#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require curl

URL="${GATEWAY_URL:-http://localhost:8080}"
info "Testing baseline route at $URL"
for i in $(seq 1 10); do
  version=$(curl -fsS "$URL/pay?amount=$((100+i))" | sed -n 's/.*"payment_version": "\([^"]*\)".*/\1/p' | head -1)
  printf 'request=%02d version=%s\n' "$i" "${version:-unknown}"
done

echo "Expected result: all requests use v1."
