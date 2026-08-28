-- ============================================================================
-- Comparaison de DEUX comptes par CLÉ NATURELLE (les UUID diffèrent après import).
-- À exécuter dans le SQL Editor de Supabase. Lecture seule — ne modifie rien.
--
-- Changez les deux e-mails ci-dessous si besoin.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- REQUÊTE 1 — RÉSUMÉ : par table, nb de lignes de chaque compte + différences.
-- Si les deux comptes sont identiques : A = B, et A_sans_B = B_sans_A = 0 partout.
-- ----------------------------------------------------------------------------
with
a as (select id from auth.users where email = 'thiebaut.eric@laposte.net'),
b as (select id from auth.users where email = 'thiebaut.eric2@laposte.net'),
-- projections par clé naturelle, compte A
films_a    as (select tmdb_id, media_type from public.films where user_id = (select id from a)),
films_b    as (select tmdb_id, media_type from public.films where user_id = (select id from b)),
seasons_a  as (select f.tmdb_id, f.media_type, s.season_number
               from public.film_seasons s join public.films f on f.id = s.film_id
               where s.user_id = (select id from a)),
seasons_b  as (select f.tmdb_id, f.media_type, s.season_number
               from public.film_seasons s join public.films f on f.id = s.film_id
               where s.user_id = (select id from b)),
hist_a     as (select f.tmdb_id, f.media_type, h.season_number, h.episode_number, h.watched_at, h.rating
               from public.history h join public.films f on f.id = h.film_id
               where h.user_id = (select id from a)),
hist_b     as (select f.tmdb_id, f.media_type, h.season_number, h.episode_number, h.watched_at, h.rating
               from public.history h join public.films f on f.id = h.film_id
               where h.user_id = (select id from b)),
coll_a     as (select f.tmdb_id, f.media_type, c.season_number, c.episode_number, c.medium
               from public.collection c join public.films f on f.id = c.film_id
               where c.user_id = (select id from a)),
coll_b     as (select f.tmdb_id, f.media_type, c.season_number, c.episode_number, c.medium
               from public.collection c join public.films f on f.id = c.film_id
               where c.user_id = (select id from b)),
wish_a     as (select f.tmdb_id, f.media_type, w.season_number
               from public.wishlist w join public.films f on f.id = w.film_id
               where w.user_id = (select id from a)),
wish_b     as (select f.tmdb_id, f.media_type, w.season_number
               from public.wishlist w join public.films f on f.id = w.film_id
               where w.user_id = (select id from b)),
fav_a      as (select person_id from public.favorites where user_id = (select id from a)),
fav_b      as (select person_id from public.favorites where user_id = (select id from b))
select 'films' as table_,
       (select count(*) from films_a) as compte_A,
       (select count(*) from films_b) as compte_B,
       (select count(*) from (select * from films_a except select * from films_b) x) as A_sans_B,
       (select count(*) from (select * from films_b except select * from films_a) x) as B_sans_A
union all select 'film_seasons',
       (select count(*) from seasons_a), (select count(*) from seasons_b),
       (select count(*) from (select * from seasons_a except select * from seasons_b) x),
       (select count(*) from (select * from seasons_b except select * from seasons_a) x)
union all select 'history',
       (select count(*) from hist_a), (select count(*) from hist_b),
       (select count(*) from (select * from hist_a except select * from hist_b) x),
       (select count(*) from (select * from hist_b except select * from hist_a) x)
union all select 'collection',
       (select count(*) from coll_a), (select count(*) from coll_b),
       (select count(*) from (select * from coll_a except select * from coll_b) x),
       (select count(*) from (select * from coll_b except select * from coll_a) x)
union all select 'wishlist',
       (select count(*) from wish_a), (select count(*) from wish_b),
       (select count(*) from (select * from wish_a except select * from wish_b) x),
       (select count(*) from (select * from wish_b except select * from wish_a) x)
union all select 'favorites',
       (select count(*) from fav_a), (select count(*) from fav_b),
       (select count(*) from (select * from fav_a except select * from fav_b) x),
       (select count(*) from (select * from fav_b except select * from fav_a) x)
order by table_;


-- ----------------------------------------------------------------------------
-- REQUÊTE 2 — DÉTAIL FILMS : quels titres sont dans un compte mais pas l'autre.
-- (exécutez-la séparément pour voir les lignes)
-- ----------------------------------------------------------------------------
with
a as (select id from auth.users where email = 'thiebaut.eric@laposte.net'),
b as (select id from auth.users where email = 'thiebaut.eric2@laposte.net')
select 'A_sans_B' as sens, f.tmdb_id, f.media_type, f.title
from public.films f
where f.user_id = (select id from a)
  and not exists (select 1 from public.films g
                  where g.user_id = (select id from b)
                    and g.tmdb_id = f.tmdb_id and g.media_type = f.media_type)
union all
select 'B_sans_A', g.tmdb_id, g.media_type, g.title
from public.films g
where g.user_id = (select id from b)
  and not exists (select 1 from public.films f
                  where f.user_id = (select id from a)
                    and f.tmdb_id = g.tmdb_id and f.media_type = g.media_type)
order by sens, media_type, tmdb_id;


-- ----------------------------------------------------------------------------
-- REQUÊTE 3 — DÉTAIL FAVORIS : personnes présentes dans un compte mais pas l'autre.
-- ----------------------------------------------------------------------------
with
a as (select id from auth.users where email = 'thiebaut.eric@laposte.net'),
b as (select id from auth.users where email = 'thiebaut.eric2@laposte.net')
select 'A_sans_B' as sens, x.person_id, x.name
from public.favorites x
where x.user_id = (select id from a)
  and not exists (select 1 from public.favorites y
                  where y.user_id = (select id from b) and y.person_id = x.person_id)
union all
select 'B_sans_A', y.person_id, y.name
from public.favorites y
where y.user_id = (select id from b)
  and not exists (select 1 from public.favorites x
                  where x.user_id = (select id from a) and x.person_id = y.person_id)
order by sens, person_id;
