-- ============================================================================
-- Mode « Mes amis » — à exécuter dans le SQL Editor du dashboard Supabase.
-- Idempotent. Remplace les politiques de lecture admin de admin.sql :
-- tout utilisateur CONNECTÉ peut désormais LIRE les bibliothèques des autres
-- (modèle assumé : cercle famille/amis, tous les comptes créés par l'admin).
-- L'ÉCRITURE reste strictement limitée à ses propres lignes (politiques
-- insert/update/delete de schema.sql inchangées).
-- ============================================================================

-- 1) Lecture ouverte aux connectés sur les 5 tables (remplace « admin select all »).
do $$
declare t text;
begin
  foreach t in array array['films','film_seasons','collection','history','favorites']
  loop
    execute format('drop policy if exists "admin select all %1$s" on public.%1$I;', t);
    execute format('drop policy if exists "friends select all %1$s" on public.%1$I;', t);
    execute format(
      'create policy "friends select all %1$s" on public.%1$I for select to authenticated using (true);', t);
  end loop;
end $$;

-- 2) Liste des autres comptes (pour l'onglet « Mes amis »). SECURITY DEFINER :
--    lit auth.users sans l'exposer ; exclut l'appelant.
create or replace function public.friends()
returns table (user_id uuid, email text)
language sql
security definer
set search_path = ''
stable
as $$
  select u.id, u.email::text
  from auth.users u
  where u.id <> auth.uid()
  order by u.email;
$$;

grant execute on function public.friends() to authenticated;
