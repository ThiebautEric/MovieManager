-- ============================================================================
-- Movie Manager — schéma Supabase (modèle normalisé films / collection / history)
-- À exécuter dans le SQL Editor du projet Supabase (Dashboard > SQL Editor).
--
-- Modèle :
--   1. films        → catalogue TMDB (un titre).
--   2. film_seasons → catalogue des saisons référencées (séries).
--   3. collection   → possessions de l'utilisateur (support + date).
--   4. history      → visionnages (LA donnée précieuse : jamais d'effacement auto).
--
-- collection et history sont TOTALEMENT indépendantes (aucun lien entre elles).
-- Seul l'utilisateur supprime dans collection/history (avec confirmation côté app).
-- Seule suppression automatique : un film/saison qui n'est plus référencé ni par
-- collection ni par history est retiré du catalogue `films` (trigger gc_orphan_films).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Nettoyage des anciennes tables (pré-refonte). Ce script est désormais
-- NON DESTRUCTIF pour les 4 tables ci-dessous (create if not exists + alter),
-- on peut donc le ré-exécuter sans perdre les données.
-- ----------------------------------------------------------------------------
drop table if exists public.watch_events     cascade;
drop table if exists public.collection_items cascade;

-- ----------------------------------------------------------------------------
-- 1. films — catalogue TMDB (métadonnées d'un titre, sans donnée utilisateur).
-- ----------------------------------------------------------------------------
create table if not exists public.films (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  tmdb_id        integer not null,
  media_type     text    not null check (media_type in ('movie', 'tv')),
  title          text    not null,
  original_title text,
  poster_path    text,
  release_year   integer,
  runtime        integer,
  overview       text,
  origin_country text,
  genres         integer[] not null default '{}',
  cast_ids       integer[] not null default '{}',
  added_at       timestamptz not null default now(),
  unique (user_id, tmdb_id, media_type)
);
-- Ajouts pour une base déjà créée (sans perte).
alter table public.films add column if not exists origin_country text;
alter table public.films add column if not exists cast_ids integer[] not null default '{}';

-- ----------------------------------------------------------------------------
-- 2. film_seasons — catalogue des saisons (séries) réellement suivies.
-- ----------------------------------------------------------------------------
create table if not exists public.film_seasons (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  film_id       uuid not null references public.films (id) on delete cascade,
  season_number integer not null,
  name          text,
  poster_path   text,
  air_year      integer,
  unique (film_id, season_number)
);

-- ----------------------------------------------------------------------------
-- 3. collection — possessions. season_number null = œuvre entière.
--    Un même titre/saison peut être possédé en plusieurs supports (DVD + Blu-ray).
-- ----------------------------------------------------------------------------
create table if not exists public.collection (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  film_id       uuid not null references public.films (id) on delete cascade,
  season_number integer,
  medium        text not null check (medium in ('dvd', 'bluray', 'digital')),
  added_at      timestamptz not null default now(),
  unique (user_id, film_id, season_number, medium)
);

-- ----------------------------------------------------------------------------
-- 4. history — visionnages. UNE LIGNE PAR VISIONNAGE. Note + commentaire par séance.
-- ----------------------------------------------------------------------------
create table if not exists public.history (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  film_id       uuid not null references public.films (id) on delete cascade,
  season_number integer,
  watched_at    timestamptz not null,
  rating        numeric(3,1) check (rating is null or (rating >= 0 and rating <= 10)),
  comment       text,
  created_at    timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 5. favorites — personnes favorites (acteurs/réalisateurs) de l'utilisateur.
-- ----------------------------------------------------------------------------
create table if not exists public.favorites (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  person_id    integer not null,
  name         text not null,
  profile_path text,
  added_at     timestamptz not null default now(),
  unique (user_id, person_id)
);

-- ----------------------------------------------------------------------------
-- Index pour les filtres/jointures fréquents.
-- ----------------------------------------------------------------------------
create index if not exists favorites_user_idx       on public.favorites (user_id);
create index if not exists films_user_idx          on public.films (user_id);
create index if not exists film_seasons_film_idx    on public.film_seasons (film_id);
create index if not exists film_seasons_user_idx    on public.film_seasons (user_id);
create index if not exists collection_user_idx      on public.collection (user_id);
create index if not exists collection_film_idx      on public.collection (film_id);
create index if not exists history_user_date_idx    on public.history (user_id, watched_at desc);
create index if not exists history_film_idx         on public.history (film_id);

-- ----------------------------------------------------------------------------
-- Ramasse-miettes (SEULE suppression automatique) : après suppression d'une
-- ligne collection ou history, si le film n'est plus référencé du tout → on
-- l'efface du catalogue (cascade sur film_seasons). Sinon, si la saison
-- concernée n'est plus référencée → on efface sa ligne film_seasons orpheline.
-- N'affecte JAMAIS collection ni history (aucun lien entre elles).
-- ----------------------------------------------------------------------------
create or replace function public.gc_orphan_films()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Film plus référencé nulle part → suppression du catalogue.
  if not exists (select 1 from public.collection where film_id = old.film_id)
     and not exists (select 1 from public.history where film_id = old.film_id) then
    delete from public.films where id = old.film_id;
    return old;
  end if;

  -- Saison concernée plus référencée → nettoyage de son catalogue.
  if old.season_number is not null
     and not exists (
       select 1 from public.collection
       where film_id = old.film_id and season_number = old.season_number
     )
     and not exists (
       select 1 from public.history
       where film_id = old.film_id and season_number = old.season_number
     ) then
    delete from public.film_seasons
      where film_id = old.film_id and season_number = old.season_number;
  end if;

  return old;
end;
$$;

drop trigger if exists gc_after_collection_delete on public.collection;
create trigger gc_after_collection_delete
  after delete on public.collection
  for each row execute function public.gc_orphan_films();

drop trigger if exists gc_after_history_delete on public.history;
create trigger gc_after_history_delete
  after delete on public.history
  for each row execute function public.gc_orphan_films();

-- ----------------------------------------------------------------------------
-- Row Level Security : chaque utilisateur ne voit/modifie que ses lignes.
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['films', 'film_seasons', 'collection', 'history', 'favorites']
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists "select own %1$s" on public.%1$I;', t);
    execute format(
      'create policy "select own %1$s" on public.%1$I for select using (auth.uid() = user_id);', t);
    execute format('drop policy if exists "insert own %1$s" on public.%1$I;', t);
    execute format(
      'create policy "insert own %1$s" on public.%1$I for insert with check (auth.uid() = user_id);', t);
    execute format('drop policy if exists "update own %1$s" on public.%1$I;', t);
    execute format(
      'create policy "update own %1$s" on public.%1$I for update using (auth.uid() = user_id) with check (auth.uid() = user_id);', t);
    execute format('drop policy if exists "delete own %1$s" on public.%1$I;', t);
    execute format(
      'create policy "delete own %1$s" on public.%1$I for delete using (auth.uid() = user_id);', t);
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- Realtime (ajout idempotent : ne ré-ajoute pas une table déjà publiée).
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['films', 'film_seasons', 'collection', 'history', 'favorites']
  loop
    if not exists (
          select 1 from pg_publication_tables
          where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
        ) then
      execute format('alter publication supabase_realtime add table public.%I;', t);
    end if;
  end loop;
end $$;
