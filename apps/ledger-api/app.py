import json
import os
import socket
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PORT = int(os.getenv("PORT", "8080"))

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(json.dumps({"service": "ledger-api", "message": fmt % args}), flush=True)

    def send_json(self, status, payload):
        body = json.dumps(payload, indent=2).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path in ("/healthz", "/readyz"):
            return self.send_json(200, {"status": "ok", "service": "ledger-api"})
        if parsed.path != "/record":
            return self.send_json(404, {"error": "use /record"})
        query = parse_qs(parsed.query)
        return self.send_json(200, {
            "recorded": True,
            "request_id": query.get("request_id", [""])[0],
            "ledger_timestamp": int(time.time()),
            "hostname": socket.gethostname(),
        })

if __name__ == "__main__":
    print(f"ledger-api listening on {PORT}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
