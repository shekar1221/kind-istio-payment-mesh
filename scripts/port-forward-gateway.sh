#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require kubectl
info "Gateway available at http://localhost:8080"
kubectl -n istio-system port-forward service/istio-ingressgateway 8080:80
