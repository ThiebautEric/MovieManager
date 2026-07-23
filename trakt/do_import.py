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
for tbl in ["history", "collection", "wishlist", "film_seasons", "films", "favorites"]:
    sup("DELETE", "/rest/v1/" + tbl, headers=AH, params="?user_id=eq." + uid)
print("base videe")

hist = load("watched-history-*.json")
rm  = {x["movie"]["ids"].get("tmdb"): x["rating"] for x in load("ratings-movies-*.json")}
epr = {x["episode"]["ids"].get("tmdb"): x["rating"] for x in load("ratings-episodes-*.json")}
# Notes de saison et de série (repli quand pas de note par épisode)
sr  = {(x["show"]["ids"].get("tmdb"), x["season"]["number"]): x["rating"]
       for x in load("ratings-seasons.json")}
showr = {x["show"]["ids"].get("tmdb"): x["rating"]
         for x in load("ratings-shows.json")}
films = {}; hrows = []; no_tmdb = []; seasons = defaultdict(list)
for h in hist:
    if h.get("type") == "movie":
        m = h["movie"]; t = m["ids"].get("tmdb")
        if not t:
            no_tmdb.append(("movie", m.get("title"), m.get("year"), h["watched_at"][:10])); continue
        films[("movie", t)] = {"title": m.get("title") or "Sans titre", "year": m.get("year")}
        hrows.append((("movie", t), None, h["watched_at"], rm.get(t), None))
    elif h.get("type") == "episode":
        sh = h["show"]; t = sh["ids"].get("tmdb"); ep = h["episode"]; sn = ep["season"]
        if not t:
            no_tmdb.append(("show", sh.get("title"), sh.get("year"), h["watched_at"][:10])); continue
        films[("tv", t)] = {"title": sh.get("title") or "Sans titre", "year": sh.get("year")}
        seasons[(t, sn)].append((h["watched_at"], ep["ids"].get("tmdb"), ep.get("number"), ep.get("title")))

# Noms/durees localises des episodes (TMDB), par saison, avec cache.
season_meta_cache = {}


def _grab_season(t, sn, lang):
    q = urllib.parse.urlencode({"api_key": TMDB, "language": lang})
    with urllib.request.urlopen("https://api.themoviedb.org/3/tv/%s/season/%s?%s" % (t, sn, q), timeout=30) as r:
        d = json.loads(r.read().decode())
    return {e.get("episode_number"): (e.get("name"), e.get("runtime")) for e in d.get("episodes", [])}


def season_meta(t, sn):
    # fr-FR, avec repli en-US quand le titre est generique (« Episode N ») :
    # TMDB renvoie ce placeholder pour les episodes non traduits.
    if (t, sn) not in season_meta_cache:
        try:
            fr = _grab_season(t, sn, "fr-FR")
            try:
                en = _grab_season(t, sn, "en-US")
            except Exception:
                en = {}
            merged = {}
            for n, (name, rt) in fr.items():
                generic = not name or (name or "").strip().lower() in ("épisode %s" % n, "episode %s" % n)
                if generic and en.get(n, (None, None))[0]:
                    name = en[n][0]
                merged[n] = (name, rt)
            season_meta_cache[(t, sn)] = merged
        except Exception:
            season_meta_cache[(t, sn)] = {}
    return season_meta_cache[(t, sn)]


# Regle : au plus UN episode note dans la saison -> convention historique
# (une entree saison par jour de visionnage, note = moyenne du jour) ;
# PLUSIEURS episodes notes -> notation par episode (une entree par episode,
# numero/nom/duree TMDB, note et date propres).
for (t, sn), eps in seasons.items():
    rated = {e for _, e, _, _ in eps if e in epr}
    if len(rated) <= 1:
        # Si exactement 1 épisode est noté dans toute la saison, sa note
        # s'applique à tous les jours (même ceux sans cet épisode).
        single_ep_rating = epr[next(iter(rated))] if rated else None
        by_day = defaultdict(list)
        for w, e, _n, _ti in eps:
            by_day[w[:10]].append((w, e))
        for lst in by_day.values():
            watched = max(w for w, _ in lst)
            rates = [epr[e] for _, e in lst if e in epr]
            rating = (round(sum(rates) / len(rates), 1) if rates
                      else single_ep_rating or sr.get((t, sn)) or showr.get(t))
            hrows.append((("tv", t), sn, watched, rating, None))
    else:
        meta = season_meta(t, sn)
        for w, e, n, ti in eps:
            name, rt = meta.get(n, (ti, None))
            hrows.append((("tv", t), sn, w, epr.get(e),
                          {"episode_number": n, "episode_name": name or ti, "episode_runtime": rt}))


def original_poster(d):
    # Affiche dans la langue ORIGINALE de l'oeuvre (repli : sans texte, puis
    # l'affiche localisee) — comme dans l'application.
    orig = d.get("original_language")
    textless = None
    for p in ((d.get("images") or {}).get("posters") or []):
        lang = p.get("iso_639_1"); path = p.get("file_path")
        if not path:
            continue
        if orig and lang == orig:
            return path
        if lang is None and textless is None:
            textless = path
    return textless or d.get("poster_path")


def fetch(key):
    typ, tid = key
    try:
        q = urllib.parse.urlencode({"api_key": TMDB, "language": "fr-FR", "append_to_response": "credits"})
        with urllib.request.urlopen("https://api.themoviedb.org/3/%s/%s?%s" % (typ, tid, q), timeout=30) as r:
            d = json.loads(r.read().decode())
        # Images SANS parametre de langue (sinon TMDB filtre a la langue
        # demandee et l'affiche originale n'apparait jamais).
        try:
            qi = urllib.parse.urlencode({"api_key": TMDB})
            with urllib.request.urlopen("https://api.themoviedb.org/3/%s/%s/images?%s" % (typ, tid, qi), timeout=30) as r:
                d["images"] = json.loads(r.read().decode())
        except Exception:
            d["images"] = {}
        isM = typ == "movie"; cred = d.get("credits") or {}
        cast = [c["id"] for c in (cred.get("cast") or []) if c.get("id")]
        directors = [c["id"] for c in (cred.get("crew") or []) if c.get("job") == "Director" and c.get("id")]
        if not directors and not isM:
            directors = [c["id"] for c in (d.get("created_by") or []) if c.get("id")]
        oc = d.get("origin_country") or []; pc = d.get("production_countries") or []
        return key, {"poster_path": original_poster(d),
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

hist_rows = []
for (k, sn, wat, rt, ep) in hrows:
    if k not in idmap:
        continue
    row = {"user_id": uid, "film_id": idmap[k], "season_number": sn, "watched_at": wat, "rating": rt}
    if ep:
        row.update(ep)
    hist_rows.append(row)
ins_hist = 0; hist_err = []
for c in chunks(hist_rows, 400):
    st, b = sup("POST", "/rest/v1/history", c, headers={**AH, "Prefer": "return=representation"})
    if st in (200, 201): ins_hist += len(json.loads(b))
    else: hist_err.append((st, b[:150]))
print("history inseres=%d erreurs lots=%d" % (ins_hist, len(hist_err)))
print("RESUME films=%d history=%d sans_tmdb=%d tmdb_fail=%d" % (ins_film, ins_hist, len(no_tmdb), len(enrich_fail)))
