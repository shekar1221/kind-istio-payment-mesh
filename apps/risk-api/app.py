import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PORT = int(os.getenv("PORT", "8080"))
APPROVAL_LIMIT = float(os.getenv("APPROVAL_LIMIT", "5000"))

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(json.dumps({"service": "risk-api", "message": fmt % args}), flush=True)

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
            return self.send_json(200, {"status": "ok", "service": "risk-api"})
        if parsed.path != "/risk":
            return self.send_json(404, {"error": "use /risk?amount=1200"})
        query = parse_qs(parsed.query)
        try:
            amount = float(query.get("amount", ["0"])[0])
        except ValueError:
            return self.send_json(400, {"error": "invalid amount"})
        decision = "APPROVE" if amount <= APPROVAL_LIMIT else "REJECT"
        score = min(99, int((amount / max(APPROVAL_LIMIT, 1)) * 70))
        return self.send_json(200, {
            "decision": decision,
            "fraud_score": score,
            "approval_limit": APPROVAL_LIMIT,
            "hostname": socket.gethostname(),
        })

if __name__ == "__main__":
    print(f"risk-api listening on {PORT}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
