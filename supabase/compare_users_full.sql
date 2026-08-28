-- ============================================================================
-- Comparaison COMPLÈTE de deux comptes (toutes les colonnes de contenu +
-- validité du lien collection -> visionnage). Lecture seule.
--
-- Exclut volontairement : id/user_id (UUID, diffèrent par nature) et
-- added_at/created_at des films (réinitialisés à now() à l'import).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- REQUÊTE 1 — DIFF DE CONTENU : nb de lignes qui diffèrent sur AU MOINS une
-- colonne de contenu. Tout à 0 = contenu strictement identique.
-- ----------------------------------------------------------------------------
with
a as (select id from auth.users where email = 'thiebaut.eric@laposte.net'),
b as (select id from auth.users where email = 'thiebaut.eric2@laposte.net'),

films_a as (select tmdb_id,media_type,title,original_title,poster_path,release_year,
                   runtime,overview,origin_country,genres,cast_ids
            from public.films where user_id=(select id from a)),
films_b as (select tmdb_id,media_type,title,original_title,poster_path,release_year,
                   runtime,overview,origin_country,genres,cast_ids
            from public.films where user_id=(select id from b)),

seasons_a as (select f.tmdb_id,f.media_type,s.season_number,s.name,s.poster_path,
                     s.air_year,s.episode_count,s.runtime_minutes
              from public.film_seasons s join public.films f on f.id=s.film_id
              where s.user_id=(select id from a)),
seasons_b as (select f.tmdb_id,f.media_type,s.season_number,s.name,s.poster_path,
                     s.air_year,s.episode_count,s.runtime_minutes
              from public.film_seasons s join public.films f on f.id=s.film_id
              where s.user_id=(select id from b)),

hist_a as (select f.tmdb_id,f.media_type,h.season_number,h.episode_number,h.episode_name,
                  h.episode_runtime,h.watched_at,h.rating,h.comment
           from public.history h join public.films f on f.id=h.film_id
           where h.user_id=(select id from a)),
hist_b as (select f.tmdb_id,f.media_type,h.season_number,h.episode_number,h.episode_name,
                  h.episode_runtime,h.watched_at,h.rating,h.comment
           from public.history h join public.films f on f.id=h.film_id
           where h.user_id=(select id from b)),

-- collection AVEC l'identité naturelle du visionnage lié (verifie history_id).
coll_a as (select f.tmdb_id,f.media_type,c.season_number,c.episode_number,c.medium,
                  hf.tmdb_id as lnk_tmdb, hf.media_type as lnk_media,
                  h.season_number as lnk_season, h.episode_number as lnk_ep,
                  h.watched_at as lnk_watched
           from public.collection c
           join public.films f on f.id=c.film_id
           left join public.history h on h.id=c.history_id
           left join public.films hf on hf.id=h.film_id
           where c.user_id=(select id from a)),
coll_b as (select f.tmdb_id,f.media_type,c.season_number,c.episode_number,c.medium,
                  hf.tmdb_id as lnk_tmdb, hf.media_type as lnk_media,
                  h.season_number as lnk_season, h.episode_number as lnk_ep,
                  h.watched_at as lnk_watched
           from public.collection c
           join public.films f on f.id=c.film_id
           left join public.history h on h.id=c.history_id
           left join public.films hf on hf.id=h.film_id
           where c.user_id=(select id from b)),

wish_a as (select f.tmdb_id,f.media_type,w.season_number
           from public.wishlist w join public.films f on f.id=w.film_id
           where w.user_id=(select id from a)),
wish_b as (select f.tmdb_id,f.media_type,w.season_number
           from public.wishlist w join public.films f on f.id=w.film_id
           where w.user_id=(select id from b)),

fav_a as (select person_id,name,profile_path from public.favorites where user_id=(select id from a)),
fav_b as (select person_id,name,profile_path from public.favorites where user_id=(select id from b))

select 'films' as table_,
       (select count(*) from (select * from films_a except select * from films_b) x) as A_diff_B,
       (select count(*) from (select * from films_b except select * from films_a) x) as B_diff_A
union all select 'film_seasons',
       (select count(*) from (select * from seasons_a except select * from seasons_b) x),
       (select count(*) from (select * from seasons_b except select * from seasons_a) x)
union all select 'history',
       (select count(*) from (select * from hist_a except select * from hist_b) x),
       (select count(*) from (select * from hist_b except select * from hist_a) x)
union all select 'collection(+lien)',
       (select count(*) from (select * from coll_a except select * from coll_b) x),
       (select count(*) from (select * from coll_b except select * from coll_a) x)
union all select 'wishlist',
       (select count(*) from (select * from wish_a except select * from wish_b) x),
       (select count(*) from (select * from wish_b except select * from wish_a) x)
union all select 'favorites',
       (select count(*) from (select * from fav_a except select * from fav_b) x),
       (select count(*) from (select * from fav_b except select * from fav_a) x)
order by table_;


-- ----------------------------------------------------------------------------
-- REQUÊTE 2 — INTÉGRITÉ DU LIEN collection.history_id (par compte).
-- Vérifie que chaque history_id non-null pointe vers un visionnage EXISTANT et
-- du MÊME film que la possession. liens_casses doit être 0 pour les deux comptes.
-- ----------------------------------------------------------------------------
with
a as (select id from auth.users where email = 'thiebaut.eric@laposte.net'),
b as (select id from auth.users where email = 'thiebaut.eric2@laposte.net')
select
  compte,
  count(*) filter (where history_id is not null)                    as liens_total,
  count(*) filter (where history_id is not null and h_id is null)   as liens_casses,       -- history_id pointe dans le vide
  count(*) filter (where history_id is not null and h_id is not null
                        and h_film <> c_film)                        as liens_mauvais_film -- lie a un autre film
from (
  select 'A' as compte, c.history_id, h.id as h_id, c.film_id as c_film, h.film_id as h_film
  from public.collection c left join public.history h on h.id=c.history_id
  where c.user_id=(select id from a)
  union all
  select 'B', c.history_id, h.id, c.film_id, h.film_id
  from public.collection c left join public.history h on h.id=c.history_id
  where c.user_id=(select id from b)
) t
group by compte
order by compte;
