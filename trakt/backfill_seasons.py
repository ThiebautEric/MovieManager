"""Rattrapage de la table film_seasons après import Trakt.

L'import (do_import.py) insère history/collection avec season_number mais ne
remplit pas film_seasons (métadonnées de saison : nom, affiche, année). Ce
script comble les trous : pour chaque (film_id, season_number) référencé par
history ou collection et absent de film_seasons, il récupère la saison sur
TMDB et insère la ligne. Rejouable sans risque (upsert sur film_id,season_number).
"""
import json, urllib.request, urllib.error, urllib.parse
from concurrent.futures import ThreadPoolExecutor

SUP = "https://msawdukkcgjkxfktthdj.supabase.co"
ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zYXdkdWtrY2dqa3hma3R0aGRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MTU3MjAsImV4cCI6MjA5NzE5MTcyMH0.0UG-Fd0SxpZM2CbVmU2e301E6UqYI8jCexurqGUVxSY"
TMDB = "3889808a354ed5f7476794b8b4abc105"


def sup(method, path, body=None, headers=None, params=""):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(SUP + path + params, data=data, method=method)
    r.add_header("apikey", ANON); r.add_header("Content-Type", "application/json")
    for k, v in (headers or {}).items():
        r.add_header(k, v)
    try:
        with urllib.request.urlopen(r, timeout=60) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def sup_all(path, select, extra=""):
    """GET paginé (PostgREST plafonne à 1000 lignes)."""
    out, offset = [], 0
    while True:
        st, b = sup("GET", path, headers=AH,
                    params="?select=%s%s&limit=1000&offset=%d" % (select, extra, offset))
        assert st == 200, (st, b[:200])
        page = json.loads(b)
        out += page
        if len(page) < 1000:
            return out
        offset += 1000


st, b = sup("POST", "/auth/v1/token", {"email": "demo@movie.app", "password": "demo123456"}, params="?grant_type=password")
auth = json.loads(b); uid = auth["user"]["id"]; AH = {"Authorization": "Bearer " + auth["access_token"]}

# (film_id, season_number) référencés par history + collection.
wanted = set()
for tbl in ("history", "collection"):
    for r in sup_all("/rest/v1/" + tbl, "film_id,season_number", "&season_number=not.is.null"):
        wanted.add((r["film_id"], r["season_number"]))

# Complètes = présentes ET episode_count renseigné ; les autres sont (re)traitées.
have = {(r["film_id"], r["season_number"])
        for r in sup_all("/rest/v1/film_seasons", "film_id,season_number,episode_count")
        if r.get("episode_count") is not None}
missing = sorted(wanted - have)
print("saisons referencees=%d completes=%d a traiter=%d" % (len(wanted), len(have), len(missing)))

# film_id -> tmdb_id (séries uniquement).
films = {r["id"]: r["tmdb_id"]
         for r in sup_all("/rest/v1/films", "id,tmdb_id,media_type", "&media_type=eq.tv")}


def fetch(key):
    film_id, sn = key
    tid = films.get(film_id)
    if tid is None:
        return key, None, "film inconnu ou pas une serie"
    try:
        q = urllib.parse.urlencode({"api_key": TMDB, "language": "fr-FR"})
        with urllib.request.urlopen(
                "https://api.themoviedb.org/3/tv/%s/season/%s?%s" % (tid, sn, q), timeout=30) as r:
            d = json.loads(r.read().decode())
        air = d.get("air_date") or ""
        eps = len(d.get("episodes") or [])
        return key, {"user_id": uid, "film_id": film_id, "season_number": sn,
                     "name": d.get("name") or None,
                     "poster_path": d.get("poster_path"),
                     "air_year": int(air[:4]) if len(air) >= 4 else None,
                     "episode_count": eps or None}, None
    except Exception as e:
        return key, None, str(e)[:60]


rows, fails = [], []
with ThreadPoolExecutor(max_workers=16) as ex:
    for key, row, err in ex.map(fetch, missing):
        if row is None:
            fails.append((key, err))
        else:
            rows.append(row)
print("TMDB ok=%d echecs=%d" % (len(rows), len(fails)))

ins = 0; errs = []
for i in range(0, len(rows), 400):
    st, b = sup("POST", "/rest/v1/film_seasons", rows[i:i + 400],
                headers={**AH, "Prefer": "resolution=merge-duplicates,return=representation"},
                params="?on_conflict=film_id,season_number")
    if st in (200, 201):
        ins += len(json.loads(b))
    else:
        errs.append((st, b[:200]))
print("inserees=%d erreurs lots=%s" % (ins, errs or "aucune"))
for k, e in fails[:10]:
    print("  echec", k, e)
