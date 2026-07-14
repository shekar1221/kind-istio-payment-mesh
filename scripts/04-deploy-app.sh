#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require kubectl
require istioctl

info "Creating namespace and service accounts"
kubectl apply -f "$ROOT_DIR/k8s/base/00-namespace.yaml"
kubectl apply -f "$ROOT_DIR/k8s/base/01-serviceaccounts.yaml"

info "Deploying payment, risk, ledger and client workloads"
kubectl apply -f "$ROOT_DIR/k8s/base/10-payment-v1.yaml"
kubectl apply -f "$ROOT_DIR/k8s/base/11-payment-v2.yaml"
kubectl apply -f "$ROOT_DIR/k8s/base/20-risk.yaml"
kubectl apply -f "$ROOT_DIR/k8s/base/30-ledger.yaml"
kubectl apply -f "$ROOT_DIR/k8s/base/40-client.yaml"

info "Applying gateway, destination rules, baseline route and telemetry"
kubectl apply -f "$ROOT_DIR/k8s/traffic/00-gateway.yaml"
kubectl apply -f "$ROOT_DIR/k8s/traffic/01-destination-rules.yaml"
kubectl apply -f "$ROOT_DIR/k8s/traffic/10-virtualservice-baseline.yaml"
kubectl apply -f "$ROOT_DIR/k8s/observability/10-telemetry.yaml"

kubectl rollout status deployment/payment-v1 -n "$NAMESPACE" --timeout=180s
kubectl rollout status deployment/payment-v2 -n "$NAMESPACE" --timeout=180s
kubectl rollout status deployment/risk-api -n "$NAMESPACE" --timeout=180s
kubectl rollout status deployment/ledger-api -n "$NAMESPACE" --timeout=180s
kubectl rollout status deployment/mesh-client -n "$NAMESPACE" --timeout=180s

info "Validating sidecars and Istio configuration"
kubectl get pods -n "$NAMESPACE"
istioctl proxy-status
istioctl analyze -A
cat <<'EOF'

Expected READY values are 2/2 because each application pod contains:
  1. application container
  2. istio-proxy (Envoy sidecar)

Run scripts/port-forward-gateway.sh in another terminal.
EOF
