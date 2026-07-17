-- ============================================================================
-- Visionnages au niveau épisode — à exécuter dans le SQL Editor Supabase.
-- Idempotent. Colonnes nulles = comportement historique (visionnage de la
-- saison entière). Un épisode noté porte son numéro, son nom et sa durée
-- (dénormalisés depuis TMDB au moment de l'ajout).
-- ============================================================================

alter table public.history add column if not exists episode_number  integer;
alter table public.history add column if not exists episode_name    text;
alter table public.history add column if not exists episode_runtime integer;
