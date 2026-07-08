"""Petit serveur statique anti-cache pour le build Flutter web.

Sert build/web en forçant les en-têtes 'no-store' : chaque rechargement (F5)
récupère toujours la dernière version, sans souci de cache navigateur.
Usage : python serve_nocache.py [port]
"""
import http.server
import os
import socketserver
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8091
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")
os.chdir(WEB_DIR)


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


# ThreadingTCPServer : une connexion lente/bloquée ne fige pas les autres
# (TCPServer simple est mono-connexion et se retrouve gelé par un onglet ouvert).
class _Server(socketserver.ThreadingTCPServer):
    daemon_threads = True
    allow_reuse_address = True


with _Server(("", PORT), NoCacheHandler) as httpd:
    print(f"Serveur anti-cache sur http://localhost:{PORT} (dossier {WEB_DIR})")
    httpd.serve_forever()
