#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require kubectl
require curl

BASE="https://raw.githubusercontent.com/istio/istio/release-1.30/samples/addons"
info "Installing Istio demo add-ons"
kubectl apply -f "$BASE/prometheus.yaml"
kubectl apply -f "$BASE/grafana.yaml"
kubectl apply -f "$BASE/jaeger.yaml"
kubectl apply -f "$BASE/kiali.yaml"

info "Waiting for dashboards"
kubectl rollout status deployment/prometheus -n istio-system --timeout=240s
kubectl rollout status deployment/grafana -n istio-system --timeout=240s
kubectl rollout status deployment/jaeger -n istio-system --timeout=240s
kubectl rollout status deployment/kiali -n istio-system --timeout=240s
kubectl get pods -n istio-system

cat <<'EOF'

Open dashboards in separate terminals:
  istioctl dashboard kiali
  istioctl dashboard grafana
  istioctl dashboard jaeger
  istioctl dashboard prometheus

Generate traffic before inspecting graphs or traces:
  ./scripts/07-generate-traffic.sh 100
EOF
