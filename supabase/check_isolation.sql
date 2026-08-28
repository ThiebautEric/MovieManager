-- ============================================================================
-- Vérifie l'ISOLATION totale entre deux comptes : aucune ligne d'un compte ne
-- référence une ligne de l'autre. Si tout est à 0, supprimer quoi que ce soit
-- dans un compte ne peut PHYSIQUEMENT pas affecter l'autre. Lecture seule.
-- ============================================================================

with
a as (select id from auth.users where email = 'thiebaut.eric@laposte.net'),
b as (select id from auth.users where email = 'thiebaut.eric2@laposte.net')

-- 0 = OK (isolation parfaite). Toute valeur > 0 = référence croisée = DANGER.
select 'films : un id appartient aux DEUX comptes' as verification,
  (select count(*) from public.films fa join public.films fb on fa.id = fb.id
   where fa.user_id = (select id from a) and fb.user_id = (select id from b)) as doit_etre_zero

union all select 'B.film_seasons pointe vers un film NON-B',
  (select count(*) from public.film_seasons s join public.films f on f.id = s.film_id
   where s.user_id = (select id from b) and f.user_id <> (select id from b))
union all select 'B.collection pointe vers un film NON-B',
  (select count(*) from public.collection c join public.films f on f.id = c.film_id
   where c.user_id = (select id from b) and f.user_id <> (select id from b))
union all select 'B.collection.history_id pointe vers un visionnage NON-B',
  (select count(*) from public.collection c join public.history h on h.id = c.history_id
   where c.user_id = (select id from b) and h.user_id <> (select id from b))
union all select 'B.history pointe vers un film NON-B',
  (select count(*) from public.history h join public.films f on f.id = h.film_id
   where h.user_id = (select id from b) and f.user_id <> (select id from b))
union all select 'B.wishlist pointe vers un film NON-B',
  (select count(*) from public.wishlist w join public.films f on f.id = w.film_id
   where w.user_id = (select id from b) and f.user_id <> (select id from b))

union all select 'A.film_seasons pointe vers un film NON-A',
  (select count(*) from public.film_seasons s join public.films f on f.id = s.film_id
   where s.user_id = (select id from a) and f.user_id <> (select id from a))
union all select 'A.collection pointe vers un film NON-A',
  (select count(*) from public.collection c join public.films f on f.id = c.film_id
   where c.user_id = (select id from a) and f.user_id <> (select id from a))
union all select 'A.collection.history_id pointe vers un visionnage NON-A',
  (select count(*) from public.collection c join public.history h on h.id = c.history_id
   where c.user_id = (select id from a) and h.user_id <> (select id from a))
union all select 'A.history pointe vers un film NON-A',
  (select count(*) from public.history h join public.films f on f.id = h.film_id
   where h.user_id = (select id from a) and f.user_id <> (select id from a))
union all select 'A.wishlist pointe vers un film NON-A',
  (select count(*) from public.wishlist w join public.films f on f.id = w.film_id
   where w.user_id = (select id from a) and f.user_id <> (select id from a))

order by verification;
