#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require kubectl

info "Enforcing STRICT mTLS"
kubectl apply -f "$ROOT_DIR/k8s/security/10-peer-authentication-strict.yaml"

info "Applying default-deny and least-privilege allow policies"
kubectl apply -f "$ROOT_DIR/k8s/security/20-default-deny.yaml"
kubectl apply -f "$ROOT_DIR/k8s/security/21-allow-ingress-to-payment.yaml"
kubectl apply -f "$ROOT_DIR/k8s/security/22-allow-payment-to-risk.yaml"
kubectl apply -f "$ROOT_DIR/k8s/security/23-allow-payment-to-ledger.yaml"
kubectl apply -f "$ROOT_DIR/k8s/security/24-allow-mesh-client-to-payment.yaml"

kubectl get peerauthentication,authorizationpolicy -n "$NAMESPACE"
istioctl x authz check deployment/payment-v1 -n "$NAMESPACE" || true
cat <<'EOF'

Validate permitted gateway traffic:
  curl -i http://localhost:8080/pay?amount=100

Validate service-account authorization from the injected client:
  kubectl exec -n payments deploy/mesh-client -c curl -- curl -s http://payment-api:8080/pay?amount=100

Apply k8s/broken/03-plaintext-client.yaml and test a non-mesh client to demonstrate STRICT mTLS rejection.
EOF
