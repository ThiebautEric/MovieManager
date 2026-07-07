import json, glob, io, os, urllib.request, urllib.parse
SUP = "https://msawdukkcgjkxfktthdj.supabase.co"
ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zYXdkdWtrY2dqa3hma3R0aGRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MTU3MjAsImV4cCI6MjA5NzE5MTcyMH0.0UG-Fd0SxpZM2CbVmU2e301E6UqYI8jCexurqGUVxSY"
TMDB = "3889808a354ed5f7476794b8b4abc105"
BASE = os.path.join(os.path.dirname(__file__), "extracted")
PINK = {1: 149193, 2: 379141, 3: 379155, 4: 379241}  # saison Trakt -> tmdb court-metrage


def load(pat):
    out = []
    for fn in sorted(glob.glob(os.path.join(BASE, pat))):
        out += json.load(io.open(fn, encoding="utf-8"))
    return out


def sup(m, p, b=None, h=None, pa=""):
    data = json.dumps(b).encode() if b is not None else None
    r = urllib.request.Request(SUP + p + pa, data=data, method=m)
    r.add_header("apikey", ANON); r.add_header("Content-Type", "application/json")
    for k, v in (h or {}).items():
        r.add_header(k, v)
    with urllib.request.urlopen(r, timeout=60) as resp:
        return resp.status, resp.read().decode()


def tmdb_movie(tid):
    q = urllib.parse.urlencode({"api_key": TMDB, "language": "fr-FR", "append_to_response": "credits"})
    d = json.loads(urllib.request.urlopen("https://api.themoviedb.org/3/movie/%s?%s" % (tid, q), timeout=30).read().decode())
    cred = d.get("credits") or {}
    cast = [c["id"] for c in (cred.get("cast") or [])[:15] if c.get("id")]
    dirs = [c["id"] for c in (cred.get("crew") or []) if c.get("job") == "Director" and c.get("id")]
    oc = d.get("origin_country") or []; pc = d.get("production_countries") or []
    return {"tmdb_id": tid, "media_type": "movie", "title": d.get("title"), "original_title": d.get("original_title"),
            "poster_path": d.get("poster_path"), "release_year": int((d.get("release_date") or "0")[:4] or 0) or None,
            "runtime": d.get("runtime"), "overview": d.get("overview") or None,
            "origin_country": oc[0] if oc else (pc[0]["iso_3166_1"] if pc else None),
            "genres": [g["id"] for g in d.get("genres", [])], "cast_ids": list(dict.fromkeys(cast + dirs))}


st, b = sup("POST", "/auth/v1/token", {"email": "demo@movie.app", "password": "demo123456"}, pa="?grant_type=password")
auth = json.loads(b); uid = auth["user"]["id"]; AH = {"Authorization": "Bearer " + auth["access_token"]}

# (tmdb_film, watched_at) à importer
todo = []
for h in load("watched-history-*.json"):
    if h.get("type") != "episode":
        continue
    title = h["show"]["title"]
    if h["show"]["ids"].get("tmdb"):
        continue  # deja importable
    if title == "The Pink Panther":
        tid = PINK.get(h["episode"]["season"])
        if tid:
            todo.append((tid, h["watched_at"]))
    elif "Dangerous Brothers" in title:
        todo.append((79276, h["watched_at"]))

cache = {}
done = []
for tid, wat in todo:
    if tid not in cache:
        film = tmdb_movie(tid)
        st, b = sup("POST", "/rest/v1/films", {**film, "user_id": uid}, h={**AH, "Prefer": "resolution=merge-duplicates,return=representation"}, pa="?on_conflict=user_id,tmdb_id,media_type")
        cache[tid] = (json.loads(b)[0]["id"], film["title"])
    fid, name = cache[tid]
    sup("POST", "/rest/v1/history", {"user_id": uid, "film_id": fid, "season_number": None, "watched_at": wat, "rating": None}, h={**AH, "Prefer": "return=minimal"})
    done.append("%s le %s" % (name, wat[:10]))
print("IMPORTES %d:" % len(done))
for d in done:
    print("  +", d)
