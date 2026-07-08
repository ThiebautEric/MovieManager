-- ============================================================================
-- Accès administrateur — à exécuter dans le SQL Editor du dashboard Supabase.
-- Idempotent : peut être rejoué sans risque. Ne touche pas à schema.sql.
--
-- Modèle : un compte est admin si son JWT porte app_metadata.role = 'admin'.
-- app_metadata n'est modifiable que côté serveur (jamais par l'utilisateur).
-- ============================================================================

-- 1) L'appelant est-il admin ? (lit la claim du JWT de la requête)
create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false);
$$;

grant execute on function public.is_admin() to authenticated;

-- 2) Politique SELECT additionnelle par table. Les politiques permissives se
--    cumulent en OR avec les « select own <table> » existantes : l'admin voit
--    tout EN LECTURE SEULE (aucune politique insert/update/delete ajoutée).
do $$
declare t text;
begin
  foreach t in array array['films','film_seasons','collection','history','favorites']
  loop
    execute format('drop policy if exists "admin select all %1$s" on public.%1$I;', t);
    execute format(
      'create policy "admin select all %1$s" on public.%1$I for select using (public.is_admin());', t);
  end loop;
end $$;

-- 3) Promotion d'un compte en admin (à exécuter UNE FOIS, après avoir créé le
--    compte par une inscription normale dans l'app ; adapter l'email).
--    ⚠ La claim n'apparaît dans le JWT qu'après reconnexion (ou refresh token).
--
-- update auth.users
--   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
--   where email = 'eric.thiebaut@ianeo.de';
