#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require kubectl

RESOURCE="txn-2026-0001"
MANIFEST="$ROOT_DIR/k8s/finalizers/10-sample-cleanup.yaml"

info "Creating a PaymentCleanup resource"
kubectl apply -f "$MANIFEST"

info "Waiting for the controller to add its finalizer"
for _ in $(seq 1 30); do
  finalizers="$(kubectl get paymentcleanup "$RESOURCE" -n "$NAMESPACE" -o jsonpath='{.metadata.finalizers}' 2>/dev/null || true)"
  [[ "$finalizers" == *"payments.example.com/archive"* ]] && break
  sleep 1
done
kubectl get paymentcleanup "$RESOURCE" -n "$NAMESPACE" -o custom-columns='NAME:.metadata.name,FINALIZERS:.metadata.finalizers,PHASE:.status.phase'

info "Deleting the resource: the API server first sets deletionTimestamp"
kubectl delete paymentcleanup "$RESOURCE" -n "$NAMESPACE" --wait=false
sleep 1
kubectl get paymentcleanup "$RESOURCE" -n "$NAMESPACE" -o yaml 2>/dev/null | sed -n '/deletionTimestamp:/p;/finalizers:/,+2p' || true

info "Waiting for cleanup and finalizer removal"
for _ in $(seq 1 45); do
  kubectl get paymentcleanup "$RESOURCE" -n "$NAMESPACE" >/dev/null 2>&1 || break
  sleep 1
done

if kubectl get paymentcleanup "$RESOURCE" -n "$NAMESPACE" >/dev/null 2>&1; then
  warn "Resource still exists. Check controller logs and RBAC."
  exit 1
fi

info "The object is deleted; the simulated external-cleanup evidence remains"
kubectl get configmap "payment-cleanup-$RESOURCE" -n "$NAMESPACE" -o yaml
