#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require kubectl

RESOURCE="txn-stuck-demo"

info "Creating a resource with a finalizer that has no controller"
kubectl apply -f "$ROOT_DIR/k8s/finalizers/20-stuck-cleanup.yaml"
kubectl delete paymentcleanup "$RESOURCE" -n "$NAMESPACE" --wait=false
sleep 2

info "The object remains Terminating because interview.demo/manual-cleanup is still present"
kubectl get paymentcleanup "$RESOURCE" -n "$NAMESPACE" -o custom-columns='NAME:.metadata.name,DELETION-TIMESTAMP:.metadata.deletionTimestamp,FINALIZERS:.metadata.finalizers'

cat <<'MESSAGE'

Diagnose before removing a finalizer:
  kubectl get paymentcleanup txn-stuck-demo -n payments -o yaml
  kubectl describe paymentcleanup txn-stuck-demo -n payments
  kubectl get events -n payments --sort-by=.lastTimestamp
  kubectl logs -n payments deploy/payment-finalizer-controller

After confirming that required external cleanup is complete, recover with:
  ./scripts/14-resolve-stuck-finalizer.sh paymentcleanup txn-stuck-demo payments interview.demo/manual-cleanup
MESSAGE
