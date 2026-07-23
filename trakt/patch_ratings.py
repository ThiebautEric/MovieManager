"""
Remplit les notes manquantes dans history en utilisant les ratings Trakt,
avec la chaîne de fallback suivante (par ordre de priorité) :
  1. rating explicite de la saison  (ratings-seasons.json)
  2. rating explicite de la série   (ratings-shows.json)
  3. si exactement 1 épisode noté dans la saison → sa note s'applique
     à toute la saison                            (ratings-episodes-*.json)
Ne touche pas aux entrées déjà notées ni aux films (movies).
"""
import json, io, glob, os, urllib.request, urllib.error

SUP  = "https://msawdukkcgjkxfktthdj.supabase.co"
ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zYXdkdWtrY2dqa3hma3R0aGRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MTU3MjAsImV4cCI6MjA5NzE5MTcyMH0.0UG-Fd0SxpZM2CbVmU2e301E6UqYI8jCexurqGUVxSY"
BASE = os.path.join(os.path.dirname(__file__), "extracted")


def load(pat):
    out = []
    for fn in sorted(glob.glob(os.path.join(BASE, pat))):
        out += json.load(io.open(fn, encoding="utf-8"))
    return out


def sup(method, path, body=None, headers=None, params=""):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(SUP + path + params, data=data, method=method)
    r.add_header("apikey", ANON)
    r.add_header("Content-Type", "application/json")
    for k, v in (headers or {}).items():
        r.add_header(k, v)
    try:
        with urllib.request.urlopen(r, timeout=60) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


# Authentification
st, b = sup("POST", "/auth/v1/token",
            {"email": "demo@movie.app", "password": "demo123456"},
            params="?grant_type=password")
auth = json.loads(b)
uid  = auth["user"]["id"]
AH   = {"Authorization": "Bearer " + auth["access_token"]}
print("connecté uid=%s" % uid)

# Notes par saison : (tmdb_show, season_number) -> rating
sr = {(x["show"]["ids"].get("tmdb"), x["season"]["number"]): x["rating"]
      for x in load("ratings-seasons.json")}
# Notes par série : tmdb_show -> rating
showr = {x["show"]["ids"].get("tmdb"): x["rating"]
         for x in load("ratings-shows.json")}

# Règle : si exactement 1 épisode est noté dans une saison, sa note
# s'applique à toute la saison (identique à la logique de do_import.py).
_ep_season_ratings = {}  # (tmdb_show, season_number) -> [rating, ...]
for x in load("ratings-episodes-*.json"):
    t  = x["show"]["ids"].get("tmdb")
    sn = x["episode"]["season"]
    _ep_season_ratings.setdefault((t, sn), []).append(x["rating"])
single_ep_season = {k: v[0] for k, v in _ep_season_ratings.items() if len(v) == 1}

print("notes saisons=%d séries=%d épisodes-uniques=%d"
      % (len(sr), len(showr), len(single_ep_season)))

# 1. Récupérer tous les films TV de l'utilisateur (tmdb_id + id interne)
st, b = sup("GET", "/rest/v1/films", headers=AH,
            params="?user_id=eq.%s&media_type=eq.tv&select=id,tmdb_id" % uid)
films_tv = {r["id"]: r["tmdb_id"] for r in json.loads(b)}
print("films tv en base=%d" % len(films_tv))

# 2. Récupérer toutes les entrées history sans note (TV uniquement)
#    On pagine par 1000
all_unrated = []
offset = 0
while True:
    film_ids = ",".join(str(i) for i in films_tv)
    st, b = sup("GET", "/rest/v1/history", headers=AH,
                params="?user_id=eq.%s&rating=is.null&film_id=in.(%s)"
                       "&select=id,film_id,season_number"
                       "&limit=1000&offset=%d" % (uid, film_ids, offset))
    batch = json.loads(b)
    if not batch:
        break
    all_unrated.extend(batch)
    offset += len(batch)
    if len(batch) < 1000:
        break

print("entrées sans note (TV)=%d" % len(all_unrated))

# 3. Pour chaque entrée, chercher la note saison puis série
updates = []
for row in all_unrated:
    tmdb = films_tv.get(row["film_id"])
    sn   = row.get("season_number")
    if tmdb is None:
        continue
    rating = sr.get((tmdb, sn)) if sn is not None else None
    if rating is None:
        rating = showr.get(tmdb)
    if rating is None and sn is not None:
        rating = single_ep_season.get((tmdb, sn))
    if rating is not None:
        updates.append({"id": row["id"], "rating": rating})

print("entrées à mettre à jour=%d" % len(updates))

# 4. PATCH par lots de 400
updated = 0
for i in range(0, len(updates), 400):
    batch = updates[i:i+400]
    for u in batch:
        st, b = sup("PATCH", "/rest/v1/history", {"rating": u["rating"]},
                    headers=AH,
                    params="?id=eq.%s&user_id=eq.%s" % (u["id"], uid))
        if st in (200, 204):
            updated += 1
        else:
            print("  erreur id=%d st=%d %s" % (u["id"], st, b[:80]))

print("DONE mis à jour=%d / %d" % (updated, len(updates)))
