#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require kubectl
require istioctl

mkdir -p "$ROOT_DIR/artifacts"
OUT="$ROOT_DIR/artifacts/diagnostic-$(date +%Y%m%d-%H%M%S).log"
{
  echo "### CLUSTER"
  kubectl cluster-info
  kubectl get nodes -o wide
  echo "### ISTIO SYSTEM"
  kubectl get all -n istio-system
  echo "### APPLICATION"
  kubectl get all -n "$NAMESPACE"
  echo "### ISTIO CONFIG"
  kubectl get gateway,virtualservice,destinationrule,peerauthentication,authorizationpolicy,telemetry -n "$NAMESPACE" -o yaml
  echo "### PROXY STATUS"
  istioctl proxy-status
  echo "### ANALYZE"
  istioctl analyze -A || true
  echo "### EVENTS"
  kubectl get events -A --sort-by=.lastTimestamp
} | tee "$OUT"

info "Diagnostic bundle written to $OUT"
