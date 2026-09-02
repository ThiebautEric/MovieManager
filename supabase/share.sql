-- ---------------------------------------------------------------------------
-- Partage public en lecture seule d'une vue (historique / « Verlauf »).
--
-- Le propriétaire crée un lien → un token opaque (UUID) est stocké avec la vue,
-- les filtres et le tri. N'importe qui possédant le lien (SANS compte) peut lire
-- l'historique du propriétaire via des RPC `SECURITY DEFINER` confinées au token.
-- Impossible de « pivoter » vers un autre utilisateur : les RPC ne prennent que
-- le token, jamais un user_id. L'anon n'a AUCUN accès direct aux tables.
--
-- Idempotent : réexécutable dans l'éditeur SQL Supabase.
-- ---------------------------------------------------------------------------

create extension if not exists pgcrypto; -- gen_random_uuid()

create table if not exists public.shares (
  token uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  view text not null check (view in ('history')), -- 'collection' pourra suivre
  filter jsonb not null default '{}'::jsonb,
  sort text,
  label text, -- description libre facultative (pour l'écran « Mes liens »)
  created_at timestamptz not null default now()
);

create index if not exists shares_owner_idx on public.shares (owner_id);

alter table public.shares enable row level security;

-- Le propriétaire gère ses liens : lister (select), créer (insert), révoquer
-- (delete). Aucun accès anon direct : tout passe par les RPC ci-dessous.
drop policy if exists "own shares select" on public.shares;
create policy "own shares select" on public.shares
  for select to authenticated using (auth.uid() = owner_id);

drop policy if exists "own shares insert" on public.shares;
create policy "own shares insert" on public.shares
  for insert to authenticated with check (auth.uid() = owner_id);

drop policy if exists "own shares delete" on public.shares;
create policy "own shares delete" on public.shares
  for delete to authenticated using (auth.uid() = owner_id);

-- Crée un lien de partage pour l'utilisateur courant → renvoie le token.
create or replace function public.create_share(
  p_view text, p_filter jsonb, p_sort text, p_label text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare t uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_view <> 'history' then raise exception 'unsupported_view'; end if;
  insert into public.shares (owner_id, view, filter, sort, label)
    values (auth.uid(), p_view, coalesce(p_filter, '{}'::jsonb), p_sort, p_label)
    returning token into t;
  return t;
end;
$$;
revoke all on function public.create_share(text, jsonb, text, text) from public;
grant execute on function public.create_share(text, jsonb, text, text) to authenticated;

-- Métadonnées d'un lien (anon) : vue + filtre + tri. Aucune ligne si le lien a
-- été révoqué (supprimé) ou n'existe pas.
create or replace function public.get_share(p_token uuid)
returns table (view text, filter jsonb, sort text, label text)
language sql
security definer
set search_path = public
stable
as $$
  select view, filter, sort, label from public.shares where token = p_token;
$$;
revoke all on function public.get_share(uuid) from public;
grant execute on function public.get_share(uuid) to anon, authenticated;

-- Données de l'historique partagé (anon), confinées au propriétaire du token.
-- Renvoie { films:[...], seasons:[...], history:[...] } — mêmes formes que les
-- tables (parsées côté client via *.fromJson). `user_id` est retiré (inutile et
-- superflu à exposer).
create or replace function public.share_history_snapshot(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_owner uuid;
  v_view text;
begin
  select owner_id, view into v_owner, v_view
    from public.shares where token = p_token;
  if v_owner is null then raise exception 'invalid_token'; end if;
  if v_view <> 'history' then raise exception 'unsupported_view'; end if;

  return jsonb_build_object(
    'films', coalesce((
      select jsonb_agg(to_jsonb(f) - 'user_id')
      from public.films f where f.user_id = v_owner), '[]'::jsonb),
    'seasons', coalesce((
      select jsonb_agg(to_jsonb(s) - 'user_id')
      from public.film_seasons s where s.user_id = v_owner), '[]'::jsonb),
    'history', coalesce((
      select jsonb_agg(to_jsonb(h) - 'user_id')
      from public.history h where h.user_id = v_owner), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.share_history_snapshot(uuid) from public;
grant execute on function public.share_history_snapshot(uuid) to anon, authenticated;
