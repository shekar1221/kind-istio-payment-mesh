#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require curl
COUNT="${1:-100}"
URL="${GATEWAY_URL:-http://localhost:8080}"
info "Generating $COUNT payment requests"
for i in $(seq 1 "$COUNT"); do
  curl -sS -o /dev/null -H "x-request-id: demo-$i" "$URL/pay?amount=$((100 + i))" || true
  sleep 0.05
done
