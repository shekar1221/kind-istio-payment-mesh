import json
import os
import socket
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlparse
from urllib.request import Request, urlopen

PORT = int(os.getenv("PORT", "8080"))
VERSION = os.getenv("VERSION", "v1")
RISK_URL = os.getenv("RISK_URL", "http://risk-api:8080/risk")
LEDGER_URL = os.getenv("LEDGER_URL", "http://ledger-api:8080/record")
DEPENDENCY_TIMEOUT = float(os.getenv("DEPENDENCY_TIMEOUT", "2.0"))
TRACE_HEADERS = {
    "x-request-id", "x-b3-traceid", "x-b3-spanid", "x-b3-parentspanid",
    "x-b3-sampled", "x-b3-flags", "b3", "traceparent", "tracestate", "baggage"
}


def call_json(url, params, inbound_headers):
    headers = {k: v for k, v in inbound_headers.items() if k.lower() in TRACE_HEADERS}
    request = Request(f"{url}?{urlencode(params)}", headers=headers)
    try:
        with urlopen(request, timeout=DEPENDENCY_TIMEOUT) as response:
            return response.status, json.loads(response.read().decode())
    except HTTPError as exc:
        return exc.code, {"error": exc.read().decode(errors="replace")}
    except (URLError, TimeoutError) as exc:
        return 503, {"error": str(exc)}


class Handler(BaseHTTPRequestHandler):
    server_version = "payment-api/1.0"

    def log_message(self, fmt, *args):
        print(json.dumps({
            "service": "payment-api", "version": VERSION,
            "client": self.client_address[0], "message": fmt % args
        }), flush=True)

    def send_json(self, status, payload):
        body = json.dumps(payload, indent=2).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.send_header("x-service-version", VERSION)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        if parsed.path in ("/healthz", "/readyz"):
            return self.send_json(200, {"status": "ok", "service": "payment-api", "version": VERSION})
        if parsed.path == "/fail":
            return self.send_json(500, {"status": "failed intentionally", "version": VERSION})
        if parsed.path == "/slow":
            seconds = min(float(query.get("seconds", ["3"])[0]), 10.0)
            time.sleep(seconds)
            return self.send_json(200, {"status": "completed", "slept_seconds": seconds, "version": VERSION})
        if parsed.path != "/pay":
            return self.send_json(404, {"error": "use /pay?amount=1200&account=A100"})

        request_id = self.headers.get("x-request-id", str(uuid.uuid4()))
        amount_text = query.get("amount", ["100"])[0]
        account = query.get("account", ["A100"])[0]
        try:
            amount = float(amount_text)
        except ValueError:
            return self.send_json(400, {"error": "amount must be numeric"})

        risk_status, risk = call_json(
            RISK_URL,
            {"amount": amount, "account": account, "request_id": request_id},
            self.headers,
        )
        if risk_status != 200 or risk.get("decision") != "APPROVE":
            return self.send_json(422 if risk_status == 200 else 503, {
                "request_id": request_id,
                "payment_version": VERSION,
                "status": "REJECTED",
                "risk": risk,
                "hostname": socket.gethostname(),
            })

        ledger_status, ledger = call_json(
            LEDGER_URL,
            {"amount": amount, "account": account, "request_id": request_id},
            self.headers,
        )
        if ledger_status != 200:
            return self.send_json(503, {
                "request_id": request_id,
                "payment_version": VERSION,
                "status": "PENDING_LEDGER",
                "risk": risk,
                "ledger": ledger,
            })

        return self.send_json(200, {
            "request_id": request_id,
            "payment_version": VERSION,
            "release_message": "enhanced fraud context" if VERSION == "v2" else "stable release",
            "status": "SUCCESS",
            "amount": amount,
            "account": account,
            "risk": risk,
            "ledger": ledger,
            "hostname": socket.gethostname(),
        })


if __name__ == "__main__":
    print(f"payment-api {VERSION} listening on {PORT}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
