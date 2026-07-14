# Installation Guide

## Host requirements

- Docker Desktop/Docker Engine running
- Kind v0.32.0 or newer
- kubectl
- curl
- At least 6 GB free memory recommended for three nodes, Istio and dashboards
- Windows: WSL2 is preferred; Git Bash also works for most commands

## Step 1 — Validate prerequisites

```bash
./scripts/00-prereq-check.sh
```

## Step 2 — Create the Kind cluster

```bash
./scripts/01-create-cluster.sh
kubectl get nodes
```

Expected: one control-plane and two worker nodes are `Ready`.

## Step 3 — Install Istio

```bash
./scripts/02-install-istio.sh
kubectl get pods -n istio-system
istioctl proxy-status
```

The project uses the `demo` profile because it is intended for learning. Production clusters should use a reviewed profile, separate gateways, resource sizing, revision-based upgrades, PodDisruptionBudgets and production-grade telemetry backends.

## Step 4 — Build and load images

```bash
./scripts/03-build-load-images.sh
```

Kind nodes use containerd inside Docker containers. Building an image on the host does not automatically make it available inside those nodes. `kind load docker-image` copies the image to all nodes.

## Step 5 — Deploy workloads

```bash
./scripts/04-deploy-app.sh
kubectl get pods -n payments
```

Expected application pods show `2/2` because the namespace label causes automatic Envoy injection.

## Step 6 — Access the app

Terminal A:

```bash
./scripts/port-forward-gateway.sh
```

Terminal B:

```bash
curl -s http://localhost:8080/pay?amount=1200 | python -m json.tool
```

## Step 7 — Add dashboards

```bash
./scripts/05-deploy-observability.sh
./scripts/07-generate-traffic.sh 100
```

Then use `istioctl dashboard kiali`, `grafana`, `jaeger` or `prometheus`.

## Windows PowerShell equivalents

```powershell
kind create cluster --name istio-lab --config kind/kind-config.yaml
istioctl install -f istio/istio-install.yaml -y
docker build -t payment-api:local apps/payment-api
docker build -t risk-api:local apps/risk-api
docker build -t ledger-api:local apps/ledger-api
kind load docker-image payment-api:local risk-api:local ledger-api:local --name istio-lab
kubectl apply -f k8s/base/00-namespace.yaml
kubectl apply -f k8s/base/01-serviceaccounts.yaml
kubectl apply -f k8s/base/10-payment-v1.yaml
kubectl apply -f k8s/base/11-payment-v2.yaml
kubectl apply -f k8s/base/20-risk.yaml
kubectl apply -f k8s/base/30-ledger.yaml
kubectl apply -f k8s/base/40-client.yaml
kubectl apply -f k8s/traffic/00-gateway.yaml
kubectl apply -f k8s/traffic/01-destination-rules.yaml
kubectl apply -f k8s/traffic/10-virtualservice-baseline.yaml
kubectl port-forward -n istio-system service/istio-ingressgateway 8080:80
```

