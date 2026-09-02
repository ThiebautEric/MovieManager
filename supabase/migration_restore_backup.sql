-- ============================================================================
-- Migration à exécuter dans le SQL Editor de Supabase.
--
-- NON DESTRUCTIF : ne supprime AUCUNE donnée existante.
--   * Bloc 1 : change un réglage de réplication (métadonnée).
--   * Bloc 2 : DÉFINIT une fonction (les DELETE qu'elle contient ne s'exécutent
--              que lorsqu'un import est lancé depuis l'app, pas à sa création).
--
-- Ouvrez ce fichier, tout sélectionner (Ctrl+A), copier, coller, Run.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- BLOC 1 — corrige le dédoublement des favoris après un ré-import.
-- (flux realtime filtré : sans ceci, les DELETE ne sont pas propagés)
-- ----------------------------------------------------------------------------
alter table public.favorites replica identity full;

-- ----------------------------------------------------------------------------
-- BLOC 2 — fonction d'import atomique (purge + remap UUID + réinsertion des
-- 6 tables dans UNE seule transaction : tout réussit, ou rien ne change).
--
-- ⚠️ DÉFINITION DUPLIQUÉE À L'IDENTIQUE dans supabase/schema.sql. Garder les
-- deux fichiers synchronisés à chaque modification de la fonction.
-- ----------------------------------------------------------------------------
create or replace function public.restore_backup(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  n_films int := 0;
  n_seasons int := 0;
  n_history int := 0;
  n_collection int := 0;
  n_wishlist int := 0;
  n_favorites int := 0;
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;

  create temp table _film_map (old_id uuid primary key, new_id uuid not null)
    on commit drop;
  create temp table _hist_map (old_id uuid primary key, new_id uuid not null)
    on commit drop;

  delete from public.films     where user_id = uid;
  delete from public.favorites where user_id = uid;

  insert into _film_map (old_id, new_id)
  select (e->>'id')::uuid, gen_random_uuid()
  from jsonb_array_elements(coalesce(payload->'films', '[]'::jsonb)) e;

  insert into public.films
    (id, user_id, tmdb_id, media_type, title, original_title, poster_path,
     release_year, runtime, overview, origin_country, genres, cast_ids)
  select
    fm.new_id, uid,
    (e->>'tmdb_id')::int,
    e->>'media_type',
    coalesce(e->>'title', 'Sans titre'),
    e->>'original_title',
    e->>'poster_path',
    (e->>'release_year')::int,
    (e->>'runtime')::int,
    e->>'overview',
    e->>'origin_country',
    coalesce((select array_agg(v::int) from jsonb_array_elements_text(e->'genres') v), '{}'),
    coalesce((select array_agg(v::int) from jsonb_array_elements_text(e->'cast_ids') v), '{}')
  from jsonb_array_elements(coalesce(payload->'films', '[]'::jsonb)) e
  join _film_map fm on fm.old_id = (e->>'id')::uuid;
  get diagnostics n_films = row_count;

  insert into public.film_seasons
    (user_id, film_id, season_number, name, poster_path, air_year,
     episode_count, runtime_minutes)
  select
    uid, fm.new_id,
    (e->>'season_number')::int,
    e->>'name',
    e->>'poster_path',
    (e->>'air_year')::int,
    (e->>'episode_count')::int,
    (e->>'runtime_minutes')::int
  from jsonb_array_elements(coalesce(payload->'film_seasons', '[]'::jsonb)) e
  join _film_map fm on fm.old_id = (e->>'film_id')::uuid;
  get diagnostics n_seasons = row_count;

  insert into _hist_map (old_id, new_id)
  select (e->>'id')::uuid, gen_random_uuid()
  from jsonb_array_elements(coalesce(payload->'history', '[]'::jsonb)) e
  where exists (
    select 1 from _film_map fm where fm.old_id = (e->>'film_id')::uuid
  );

  insert into public.history
    (id, user_id, film_id, season_number, watched_at, rating, comment,
     episode_number, episode_name, episode_runtime)
  select
    hm.new_id, uid, fm.new_id,
    (e->>'season_number')::int,
    (e->>'watched_at')::timestamptz,
    (e->>'rating')::numeric,
    e->>'comment',
    (e->>'episode_number')::int,
    e->>'episode_name',
    (e->>'episode_runtime')::int
  from jsonb_array_elements(coalesce(payload->'history', '[]'::jsonb)) e
  join _film_map fm on fm.old_id = (e->>'film_id')::uuid
  join _hist_map hm on hm.old_id = (e->>'id')::uuid;
  get diagnostics n_history = row_count;

  insert into public.collection
    (user_id, film_id, season_number, episode_number, history_id, medium, added_at)
  select
    uid, fm.new_id,
    (e->>'season_number')::int,
    (e->>'episode_number')::int,
    hm.new_id,
    e->>'medium',
    coalesce((e->>'added_at')::timestamptz, now())
  from jsonb_array_elements(coalesce(payload->'collection', '[]'::jsonb)) e
  join _film_map fm on fm.old_id = (e->>'film_id')::uuid
  left join _hist_map hm on hm.old_id = (e->>'history_id')::uuid;
  get diagnostics n_collection = row_count;

  insert into public.wishlist
    (user_id, film_id, season_number, added_at)
  select
    uid, fm.new_id,
    (e->>'season_number')::int,
    coalesce((e->>'added_at')::timestamptz, now())
  from jsonb_array_elements(coalesce(payload->'wishlist', '[]'::jsonb)) e
  join _film_map fm on fm.old_id = (e->>'film_id')::uuid;
  get diagnostics n_wishlist = row_count;

  insert into public.favorites
    (user_id, person_id, name, profile_path, added_at)
  select
    uid,
    (e->>'person_id')::int,
    coalesce(e->>'name', ''),
    e->>'profile_path',
    coalesce((e->>'added_at')::timestamptz, now())
  from jsonb_array_elements(coalesce(payload->'favorites', '[]'::jsonb)) e;
  get diagnostics n_favorites = row_count;

  return jsonb_build_object(
    'films',      n_films,
    'seasons',    n_seasons,
    'history',    n_history,
    'collection', n_collection,
    'wishlist',   n_wishlist,
    'favorites',  n_favorites
  );
end;
$$;

revoke all on function public.restore_backup(jsonb) from public;
grant execute on function public.restore_backup(jsonb) to authenticated;
