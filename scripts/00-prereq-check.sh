#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

for cmd in docker kind kubectl curl; do require "$cmd"; done

docker info >/dev/null 2>&1 || fail "Docker daemon is not reachable"
info "Detected versions"
docker --version
kind version
kubectl version --client
curl --version | head -1

cat <<'EOF'

Recommended baseline:
  kind       v0.32.0+
  Kubernetes v1.35.x
  Istio      v1.30.2

On Windows, run these scripts in WSL2 or Git Bash with Docker Desktop enabled.
EOF
