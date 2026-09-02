-- ============================================================================
-- Diagnostic : trouver le trigger qui insère dans `collection` lors d'un DELETE
-- sur `history` (erreur "duplicate key ... collection_film_season_medium_uniq").
-- Lecture seule. Lancer chaque requête et coller les résultats.
-- ============================================================================

-- A. Tous les triggers des tables de l'app (nom, table, moment, événement).
select event_object_table as "table", trigger_name, action_timing, event_manipulation
from information_schema.triggers
where trigger_schema = 'public'
order by 1, 2;

-- B. Le CODE de toutes les fonctions de trigger du schéma public
--    (c'est là qu'on verra le INSERT INTO collection coupable).
select proname as fonction, pg_get_functiondef(oid) as definition
from pg_proc
where pronamespace = 'public'::regnamespace
  and prorettype = 'trigger'::regtype
order by proname;

-- C. La contrainte en cause (colonnes exactes).
select conrelid::regclass as "table", conname, pg_get_constraintdef(oid) as definition
from pg_constraint
where conname = 'collection_film_season_medium_uniq';
