#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require kind
require kubectl

if kind get clusters | grep -qx "$CLUSTER_NAME"; then
  warn "Kind cluster $CLUSTER_NAME already exists; reusing it"
else
  info "Creating the three-node Kind cluster"
  kind create cluster --name "$CLUSTER_NAME" --config "$ROOT_DIR/kind/kind-config.yaml"
fi

kubectl config use-context "kind-$CLUSTER_NAME"
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl get nodes -o wide
