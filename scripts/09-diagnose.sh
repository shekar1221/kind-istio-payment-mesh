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
  echo "### FINALIZERS"
  kubectl get crd paymentcleanups.payments.example.com -o yaml 2>/dev/null || true
  kubectl get paymentcleanups -n "$NAMESPACE" -o yaml 2>/dev/null || true
  kubectl get deployment payment-finalizer-controller -n "$NAMESPACE" -o yaml 2>/dev/null || true
  kubectl logs -n "$NAMESPACE" deployment/payment-finalizer-controller --tail=200 2>/dev/null || true
  echo "### PROXY STATUS"
  istioctl proxy-status
  echo "### ANALYZE"
  istioctl analyze -A || true
  echo "### EVENTS"
  kubectl get events -A --sort-by=.lastTimestamp
} | tee "$OUT"

info "Diagnostic bundle written to $OUT"
