#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require docker
require kind

info "Building local service images"
docker build -t payment-api:local "$ROOT_DIR/apps/payment-api"
docker build -t risk-api:local "$ROOT_DIR/apps/risk-api"
docker build -t ledger-api:local "$ROOT_DIR/apps/ledger-api"

info "Loading images into every Kind node"
kind load docker-image payment-api:local risk-api:local ledger-api:local --name "$CLUSTER_NAME"
