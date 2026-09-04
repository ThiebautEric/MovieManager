-- ============================================================================
-- Migration « Sagas favorites » — à exécuter dans le SQL Editor de Supabase.
--
-- AUTO-SUFFISANTE : exécuter CE SEUL fichier applique tout ce qui est requis
--   * colonne films.collection_id (filtre « saga favorite »)
--   * table favorite_collections (+ RLS, index, realtime, replica identity)
--   * restore_backup à jour (7 tables + collection_id + added_at + created_at)
-- Elle REMPLACE l'ancienne migration_restore_backup.sql (qu'elle inclut).
--
-- Idempotente (if not exists / create or replace) et NON destructive.
-- Ctrl+A, copier, coller, Run.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Colonne saga sur les films.
-- ----------------------------------------------------------------------------
alter table public.films add column if not exists collection_id integer;

-- ----------------------------------------------------------------------------
-- 2. Table des sagas favorites (collections TMDB de films).
-- ----------------------------------------------------------------------------
create table if not exists public.favorite_collections (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  collection_id integer not null,
  name          text not null,
  poster_path   text,
  added_at      timestamptz not null default now(),
  unique (user_id, collection_id)
);
create index if not exists favorite_collections_user_idx
  on public.favorite_collections (user_id);
-- REPLICA IDENTITY FULL : indispensable pour que les DELETE passent le filtre
-- realtime .eq('user_id', …) (cf. favorites).
alter table public.favorite_collections replica identity full;

-- ----------------------------------------------------------------------------
-- 3. RLS : chaque utilisateur ne voit/modifie que ses lignes.
-- ----------------------------------------------------------------------------
alter table public.favorite_collections enable row level security;
drop policy if exists "select own favorite_collections" on public.favorite_collections;
create policy "select own favorite_collections" on public.favorite_collections
  for select using (auth.uid() = user_id);
drop policy if exists "insert own favorite_collections" on public.favorite_collections;
create policy "insert own favorite_collections" on public.favorite_collections
  for insert with check (auth.uid() = user_id);
drop policy if exists "update own favorite_collections" on public.favorite_collections;
create policy "update own favorite_collections" on public.favorite_collections
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "delete own favorite_collections" on public.favorite_collections;
create policy "delete own favorite_collections" on public.favorite_collections
  for delete using (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 4. Realtime (ajout idempotent).
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime' and schemaname = 'public'
          and tablename = 'favorite_collections'
      ) then
    alter publication supabase_realtime add table public.favorite_collections;
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 5. restore_backup — version à jour. DOIT rester identique à la copie de
--    supabase/schema.sql et supabase/migration_restore_backup.sql.
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
  n_favorite_collections int := 0;
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;

  create temp table _film_map (old_id uuid primary key, new_id uuid not null)
    on commit drop;
  create temp table _hist_map (old_id uuid primary key, new_id uuid not null)
    on commit drop;

  delete from public.films                where user_id = uid;
  delete from public.favorites            where user_id = uid;
  delete from public.favorite_collections where user_id = uid;

  insert into _film_map (old_id, new_id)
  select (e->>'id')::uuid, gen_random_uuid()
  from jsonb_array_elements(coalesce(payload->'films', '[]'::jsonb)) e;

  insert into public.films
    (id, user_id, tmdb_id, media_type, title, original_title, poster_path,
     release_year, runtime, overview, origin_country, genres, cast_ids,
     collection_id, added_at)
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
    coalesce((select array_agg(v::int) from jsonb_array_elements_text(e->'cast_ids') v), '{}'),
    (e->>'collection_id')::int,
    coalesce((e->>'added_at')::timestamptz, now())
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
     episode_number, episode_name, episode_runtime, created_at)
  select
    hm.new_id, uid, fm.new_id,
    (e->>'season_number')::int,
    (e->>'watched_at')::timestamptz,
    (e->>'rating')::numeric,
    e->>'comment',
    (e->>'episode_number')::int,
    e->>'episode_name',
    (e->>'episode_runtime')::int,
    coalesce((e->>'created_at')::timestamptz, now())
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

  insert into public.favorite_collections
    (user_id, collection_id, name, poster_path, added_at)
  select
    uid,
    (e->>'collection_id')::int,
    coalesce(e->>'name', ''),
    e->>'poster_path',
    coalesce((e->>'added_at')::timestamptz, now())
  from jsonb_array_elements(coalesce(payload->'favorite_collections', '[]'::jsonb)) e;
  get diagnostics n_favorite_collections = row_count;

  return jsonb_build_object(
    'films',      n_films,
    'seasons',    n_seasons,
    'history',    n_history,
    'collection', n_collection,
    'wishlist',   n_wishlist,
    'favorites',  n_favorites,
    'favorite_collections', n_favorite_collections
  );
end;
$$;

revoke all on function public.restore_backup(jsonb) from public;
grant execute on function public.restore_backup(jsonb) to authenticated;
