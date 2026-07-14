#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require kubectl
require docker
require kind

info "Building and loading the finalizer controller image"
docker build -t payment-finalizer-controller:local "$ROOT_DIR/apps/finalizer-controller"
kind load docker-image payment-finalizer-controller:local --name "$CLUSTER_NAME"

info "Installing PaymentCleanup CRD"
kubectl apply -f "$ROOT_DIR/k8s/finalizers/00-crd.yaml"
kubectl wait --for=condition=Established crd/paymentcleanups.payments.example.com --timeout=90s

info "Deploying finalizer controller RBAC and workload"
kubectl apply -f "$ROOT_DIR/k8s/finalizers/01-rbac.yaml"
kubectl apply -f "$ROOT_DIR/k8s/finalizers/02-controller.yaml"
kubectl rollout status deployment/payment-finalizer-controller -n "$NAMESPACE" --timeout=180s

cat <<'MESSAGE'

Finalizer lab installed.
Run:
  ./scripts/12-demo-finalizer.sh
  ./scripts/13-demo-stuck-finalizer.sh

Controller logs:
  kubectl logs -n payments deploy/payment-finalizer-controller -f
MESSAGE
