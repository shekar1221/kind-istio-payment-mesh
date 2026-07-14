#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require kubectl
require curl

if ! command -v istioctl >/dev/null 2>&1; then
  info "Downloading istioctl ${ISTIO_VERSION}"
  WORK_DIR="$(mktemp -d)"
  (
    cd "$WORK_DIR"
    curl -L "https://istio.io/downloadIstio" | ISTIO_VERSION="$ISTIO_VERSION" sh -
  )
  mkdir -p "$ROOT_DIR/bin"
  cp "$WORK_DIR/istio-${ISTIO_VERSION}/bin/istioctl" "$ROOT_DIR/bin/istioctl"
  chmod +x "$ROOT_DIR/bin/istioctl"
fi

info "Installing Istio ${ISTIO_VERSION} with the demo profile and Jaeger provider"
istioctl install -f "$ROOT_DIR/istio/istio-install.yaml" -y
kubectl rollout status deployment/istiod -n istio-system --timeout=180s
kubectl rollout status deployment/istio-ingressgateway -n istio-system --timeout=180s
istioctl verify-install
kubectl get pods -n istio-system
