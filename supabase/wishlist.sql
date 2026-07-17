-- ============================================================================
-- Pense-bête (wishlist) — à exécuter dans le SQL Editor du dashboard Supabase.
-- Idempotent : ré-exécutable sans risque. Migration complète pour une base
-- existante ; schema.sql contient les mêmes définitions pour une base neuve.
--
-- Table des titres/saisons « à voir ou à acheter plus tard », convertibles
-- côté app en possession (collection) ou visionnage (history).
-- ============================================================================

create table if not exists public.wishlist (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  film_id       uuid not null references public.films (id) on delete cascade,
  season_number integer,
  added_at      timestamptz not null default now(),
  unique (user_id, film_id, season_number)
);
create index if not exists wishlist_user_idx on public.wishlist (user_id);
create index if not exists wishlist_film_idx on public.wishlist (film_id);

-- ----------------------------------------------------------------------------
-- Row Level Security : écriture sur ses propres lignes uniquement ; lecture
-- ouverte aux connectés (mode « Mes amis »), comme les autres tables.
-- ----------------------------------------------------------------------------
alter table public.wishlist enable row level security;
drop policy if exists "select own wishlist" on public.wishlist;
create policy "select own wishlist" on public.wishlist
  for select using (auth.uid() = user_id);
drop policy if exists "insert own wishlist" on public.wishlist;
create policy "insert own wishlist" on public.wishlist
  for insert with check (auth.uid() = user_id);
drop policy if exists "update own wishlist" on public.wishlist;
create policy "update own wishlist" on public.wishlist
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "delete own wishlist" on public.wishlist;
create policy "delete own wishlist" on public.wishlist
  for delete using (auth.uid() = user_id);
drop policy if exists "friends select all wishlist" on public.wishlist;
create policy "friends select all wishlist" on public.wishlist
  for select to authenticated using (true);

-- ----------------------------------------------------------------------------
-- GC : un film référencé uniquement par le pense-bête ne doit pas être purgé
-- (remplace la fonction de schema.sql ; les triggers collection/history
-- existants pointent déjà dessus).
-- ----------------------------------------------------------------------------
create or replace function public.gc_orphan_films()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.collection where film_id = old.film_id)
     and not exists (select 1 from public.history where film_id = old.film_id)
     and not exists (select 1 from public.wishlist where film_id = old.film_id) then
    delete from public.films where id = old.film_id;
    return old;
  end if;

  if old.season_number is not null
     and not exists (
       select 1 from public.collection
       where film_id = old.film_id and season_number = old.season_number
     )
     and not exists (
       select 1 from public.history
       where film_id = old.film_id and season_number = old.season_number
     )
     and not exists (
       select 1 from public.wishlist
       where film_id = old.film_id and season_number = old.season_number
     ) then
    delete from public.film_seasons
      where film_id = old.film_id and season_number = old.season_number;
  end if;

  return old;
end;
$$;

drop trigger if exists gc_after_wishlist_delete on public.wishlist;
create trigger gc_after_wishlist_delete
  after delete on public.wishlist
  for each row execute function public.gc_orphan_films();

-- ----------------------------------------------------------------------------
-- Realtime (idempotent), cohérent avec les autres tables.
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'wishlist'
      ) then
    alter publication supabase_realtime add table public.wishlist;
  end if;
end $$;
