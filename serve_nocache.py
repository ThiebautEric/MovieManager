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


with socketserver.TCPServer(("", PORT), NoCacheHandler) as httpd:
    print(f"Serveur anti-cache sur http://localhost:{PORT} (dossier {WEB_DIR})")
    httpd.serve_forever()
