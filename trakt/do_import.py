import json, glob, io, os, urllib.request, urllib.error, urllib.parse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor

SUP = "https://msawdukkcgjkxfktthdj.supabase.co"
ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zYXdkdWtrY2dqa3hma3R0aGRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MTU3MjAsImV4cCI6MjA5NzE5MTcyMH0.0UG-Fd0SxpZM2CbVmU2e301E6UqYI8jCexurqGUVxSY"
TMDB = "3889808a354ed5f7476794b8b4abc105"
BASE = os.path.join(os.path.dirname(__file__), "extracted")


def load(pat):
    out = []
    for fn in sorted(glob.glob(os.path.join(BASE, pat))):
        out += json.load(io.open(fn, encoding="utf-8"))
    return out


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


st, b = sup("POST", "/auth/v1/token", {"email": "demo@movie.app", "password": "demo123456"}, params="?grant_type=password")
auth = json.loads(b); uid = auth["user"]["id"]; AH = {"Authorization": "Bearer " + auth["access_token"]}
for tbl in ["history", "collection", "film_seasons", "films", "favorites"]:
    sup("DELETE", "/rest/v1/" + tbl, headers=AH, params="?user_id=eq." + uid)
print("base videe")

hist = load("watched-history-*.json")
rm = {x["movie"]["ids"].get("tmdb"): x["rating"] for x in load("ratings-movies-*.json")}
epr = {x["episode"]["ids"].get("tmdb"): x["rating"] for x in load("ratings-episodes-*.json")}
films = {}; hrows = []; no_tmdb = []; groups = defaultdict(list)
for h in hist:
    if h.get("type") == "movie":
        m = h["movie"]; t = m["ids"].get("tmdb")
        if not t:
            no_tmdb.append(("movie", m.get("title"), m.get("year"), h["watched_at"][:10])); continue
        films[("movie", t)] = {"title": m.get("title") or "Sans titre", "year": m.get("year")}
        hrows.append((("movie", t), None, h["watched_at"], rm.get(t)))
    elif h.get("type") == "episode":
        sh = h["show"]; t = sh["ids"].get("tmdb"); sn = h["episode"]["season"]
        if not t:
            no_tmdb.append(("show", sh.get("title"), sh.get("year"), h["watched_at"][:10])); continue
        films[("tv", t)] = {"title": sh.get("title") or "Sans titre", "year": sh.get("year")}
        groups[(t, sn, h["watched_at"][:10])].append((h["watched_at"], h["episode"]["ids"].get("tmdb")))
for (t, sn, _d), eps in groups.items():
    watched = max(w for w, _ in eps)
    rates = [epr[e] for _, e in eps if e in epr]
    hrows.append((("tv", t), sn, watched, round(sum(rates) / len(rates), 1) if rates else None))


def fetch(key):
    typ, tid = key
    try:
        q = urllib.parse.urlencode({"api_key": TMDB, "language": "fr-FR", "append_to_response": "credits"})
        with urllib.request.urlopen("https://api.themoviedb.org/3/%s/%s?%s" % (typ, tid, q), timeout=30) as r:
            d = json.loads(r.read().decode())
        isM = typ == "movie"; cred = d.get("credits") or {}
        cast = [c["id"] for c in (cred.get("cast") or []) if c.get("id")]
        directors = [c["id"] for c in (cred.get("crew") or []) if c.get("job") == "Director" and c.get("id")]
        if not directors and not isM:
            directors = [c["id"] for c in (d.get("created_by") or []) if c.get("id")]
        oc = d.get("origin_country") or []; pc = d.get("production_countries") or []
        return key, {"poster_path": d.get("poster_path"),
                     "origin_country": oc[0] if oc else (pc[0]["iso_3166_1"] if pc else None),
                     "genres": [g["id"] for g in d.get("genres", [])],
                     "cast_ids": list(dict.fromkeys(cast + directors)),
                     "runtime": d.get("runtime") if isM else ((d.get("episode_run_time") or [None])[0]),
                     "overview": d.get("overview") or None,
                     "original_title": (d.get("original_title") if isM else d.get("original_name")) or None}, None
    except Exception as e:
        return key, None, str(e)[:60]


enriched = {}; enrich_fail = []
with ThreadPoolExecutor(max_workers=16) as ex:
    for key, meta, err in ex.map(fetch, list(films.keys())):
        if meta is None: enrich_fail.append((key, films[key]["title"], err))
        else: enriched[key] = meta
print("enrichis ok=%d echecs TMDB=%d" % (len(enriched), len(enrich_fail)))

META = ["poster_path", "origin_country", "genres", "cast_ids", "runtime", "overview", "original_title"]
DEF = {"poster_path": None, "origin_country": None, "genres": [], "cast_ids": [], "runtime": None, "overview": None, "original_title": None}
film_rows = []
for key, info in films.items():
    typ, t = key
    row = {"user_id": uid, "tmdb_id": t, "media_type": typ, "title": info["title"], "release_year": info["year"]}
    m = enriched.get(key, {})
    for k in META: row[k] = m.get(k, DEF[k])
    film_rows.append(row)


def chunks(l, n):
    for i in range(0, len(l), n): yield l[i:i + n]


idmap = {}; ins_film = 0; film_err = []
for c in chunks(film_rows, 400):
    st, b = sup("POST", "/rest/v1/films", c, headers={**AH, "Prefer": "resolution=merge-duplicates,return=representation"}, params="?on_conflict=user_id,tmdb_id,media_type")
    if st in (200, 201):
        for r in json.loads(b): idmap[(r["media_type"], r["tmdb_id"])] = r["id"]; ins_film += 1
    else: film_err.append((st, b[:150]))
print("films inseres=%d erreurs lots=%d" % (ins_film, len(film_err)))

hist_rows = [{"user_id": uid, "film_id": idmap[k], "season_number": sn, "watched_at": wat, "rating": rt} for (k, sn, wat, rt) in hrows if k in idmap]
ins_hist = 0; hist_err = []
for c in chunks(hist_rows, 400):
    st, b = sup("POST", "/rest/v1/history", c, headers={**AH, "Prefer": "return=representation"})
    if st in (200, 201): ins_hist += len(json.loads(b))
    else: hist_err.append((st, b[:150]))
print("history inseres=%d erreurs lots=%d" % (ins_hist, len(hist_err)))
print("RESUME films=%d history=%d sans_tmdb=%d tmdb_fail=%d" % (ins_film, ins_hist, len(no_tmdb), len(enrich_fail)))
