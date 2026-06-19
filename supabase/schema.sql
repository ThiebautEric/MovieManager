-- ============================================================================
-- Movie Manager — schéma Supabase
-- À exécuter dans le SQL Editor du projet Supabase (Dashboard > SQL Editor).
-- ============================================================================

-- Table principale : un item = un film/série dans la collection d'un utilisateur.
create table if not exists public.collection_items (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  tmdb_id       integer not null,
  media_type    text    not null check (media_type in ('movie', 'tv')),
  title         text    not null,
  poster_path   text,
  release_year  integer,
  genres        integer[] not null default '{}',
  owned         boolean not null default false,
  owned_at      timestamptz,
  watched       boolean not null default false,
  user_rating   numeric(3,1) check (user_rating is null or (user_rating >= 0 and user_rating <= 10)),
  notes         text,
  added_at      timestamptz not null default now(),
  watched_at    timestamptz,                 -- dernier visionnage (dérivé, compat.)
  watch_dates   timestamptz[] not null default '{}',  -- toutes les dates de visionnage
  -- Un même média ne peut apparaître qu'une fois par utilisateur.
  unique (user_id, tmdb_id, media_type)
);

-- Migration pour un projet déjà créé (sans risque si déjà appliquée) :
alter table public.collection_items
  add column if not exists owned_at    timestamptz,
  add column if not exists watch_dates timestamptz[] not null default '{}';

-- Index pour les requêtes/filtres fréquents.
create index if not exists collection_items_user_id_idx     on public.collection_items (user_id);
create index if not exists collection_items_user_watched_idx on public.collection_items (user_id, watched);
create index if not exists collection_items_user_year_idx    on public.collection_items (user_id, release_year);

-- ----------------------------------------------------------------------------
-- Row Level Security : chaque utilisateur ne voit/modifie que ses propres lignes.
-- ----------------------------------------------------------------------------
alter table public.collection_items enable row level security;

drop policy if exists "select own items" on public.collection_items;
create policy "select own items"
  on public.collection_items for select
  using (auth.uid() = user_id);

drop policy if exists "insert own items" on public.collection_items;
create policy "insert own items"
  on public.collection_items for insert
  with check (auth.uid() = user_id);

drop policy if exists "update own items" on public.collection_items;
create policy "update own items"
  on public.collection_items for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "delete own items" on public.collection_items;
create policy "delete own items"
  on public.collection_items for delete
  using (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- (Optionnel) Activer Realtime pour rafraîchir la collection en temps réel.
-- À faire aussi dans Dashboard > Database > Replication si nécessaire.
-- ----------------------------------------------------------------------------
alter publication supabase_realtime add table public.collection_items;
