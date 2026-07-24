#!/usr/bin/env python3
"""Serve Flutter web build with COOP/COEP headers for WASM SharedArrayBuffer support."""
import http.server
import os
import socketserver

PORT = 8080
WEB_DIR = os.path.join(os.path.dirname(__file__), "build", "web")

class COOPHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        super().end_headers()

if __name__ == "__main__":
    os.chdir(WEB_DIR)
    with socketserver.TCPServer(("", PORT), COOPHandler) as httpd:
        print(f"Serving at http://localhost:{PORT} with COOP/COEP headers")
        httpd.serve_forever()
