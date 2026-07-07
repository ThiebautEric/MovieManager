import json, glob, io, os, urllib.request
from collections import defaultdict
BASE = os.path.join(os.path.dirname(__file__), "extracted")
SUP = "https://msawdukkcgjkxfktthdj.supabase.co"
ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zYXdkdWtrY2dqa3hma3R0aGRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MTU3MjAsImV4cCI6MjA5NzE5MTcyMH0.0UG-Fd0SxpZM2CbVmU2e301E6UqYI8jCexurqGUVxSY"


def load(pat):
    out = []
    for fn in sorted(glob.glob(os.path.join(BASE, pat))):
        out += json.load(io.open(fn, encoding="utf-8"))
    return out


trakt = defaultdict(int)
for h in load("watched-history-*.json"):
    trakt[h["watched_at"][:4]] += 1

data = json.dumps({"email": "demo@movie.app", "password": "demo123456"}).encode()
ar = urllib.request.Request(SUP + "/auth/v1/token?grant_type=password", data=data, method="POST")
ar.add_header("apikey", ANON); ar.add_header("Content-Type", "application/json")
tok = json.loads(urllib.request.urlopen(ar).read().decode())["access_token"]
db = defaultdict(int); frm = 0
while True:
    r = urllib.request.Request(SUP + "/rest/v1/history?select=watched_at&order=id")
    r.add_header("apikey", ANON); r.add_header("Authorization", "Bearer " + tok); r.add_header("Range", "%d-%d" % (frm, frm + 999))
    rows = json.loads(urllib.request.urlopen(r).read().decode())
    for x in rows:
        db[x["watched_at"][:4]] += 1
    if len(rows) < 1000: break
    frm += 1000

years = sorted(set(list(trakt) + list(db)), reverse=True)
print("Annee | Trakt | Base | ecart")
ta = tb = 0
for y in years:
    print("%s | %5d | %5d | %+d" % (y, trakt[y], db[y], db[y] - trakt[y]))
    ta += trakt[y]; tb += db[y]
print("TOTAL | %5d | %5d | %+d" % (ta, tb, tb - ta))
