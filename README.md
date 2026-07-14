# Kind + Istio Service Mesh Project — BFSI Payment Flow

A hands-on, interview-ready service mesh lab that runs on a local multi-node **Kind** cluster with **Istio sidecars**.

The application models a payment transaction:

```text
Client
  |
  v
Istio Ingress Gateway
  |
  v
payment-api (v1 / v2 canary)
  |                     |
  v                     v
risk-api             ledger-api
```

The project demonstrates:

- Automatic Envoy sidecar injection
- Istio Gateway and VirtualService
- DestinationRule subsets, canary routing, header routing and mirroring
- Retries, timeout, delay fault injection and circuit-breaking settings
- STRICT mutual TLS and workload identity
- Default-deny and least-privilege AuthorizationPolicy
- Prometheus, Grafana, Kiali and Jaeger lab add-ons
- Access logs, distributed tracing and proxy diagnostics
- Real troubleshooting scenarios and interview questions

## Tested design baseline

| Component | Version/baseline |
|---|---|
| Kind | v0.32.0 or newer |
| Kubernetes node image | v1.35.5 |
| Istio | 1.30.2 |
| Mesh mode | Sidecar |
| Host environment | Linux, macOS, or Windows with Docker Desktop + WSL2/Git Bash |

> The add-ons in this repository are learning/demo installations, not production installations.

## Repository map

```text
apps/                       Python microservices and Dockerfiles
kind/                       Multi-node Kind configuration
istio/                      Istio installation profile
k8s/base/                   Namespace, service accounts and workloads
k8s/traffic/                Baseline, canary, header, fault and mirror routes
k8s/security/               mTLS and authorization policies
k8s/observability/          Access logging and trace sampling
k8s/broken/                 Intentionally broken examples
scripts/                    Build, deploy, test, diagnose and cleanup scripts
docs/                       Detailed learning and interview documentation
```

## Fast path

Run from the repository root in WSL, Linux, macOS, or Git Bash:

```bash
chmod +x scripts/*.sh
./scripts/00-prereq-check.sh
./scripts/01-create-cluster.sh
./scripts/02-install-istio.sh
./scripts/03-build-load-images.sh
./scripts/04-deploy-app.sh
```

Open a second terminal and expose the gateway:

```bash
./scripts/port-forward-gateway.sh
```

Test from the first terminal:

```bash
curl -s http://localhost:8080/pay?amount=1200 | python -m json.tool
./scripts/06-test-baseline.sh
```

Deploy observability add-ons:

```bash
./scripts/05-deploy-observability.sh
```

Open dashboards in separate terminals:

```bash
istioctl dashboard kiali
istioctl dashboard grafana
istioctl dashboard jaeger
istioctl dashboard prometheus
```

## Lab sequence

1. **Baseline:** all payment traffic goes to v1.
2. **Canary:** split traffic 80% to v1 and 20% to v2.
3. **Header routing:** requests with `x-release: v2` go to v2.
4. **Fault injection:** requests with `x-chaos: delay` receive a 3-second delay.
5. **Mirroring:** send a shadow copy to v2 while returning v1's response.
6. **mTLS:** enforce STRICT service-to-service encryption.
7. **Authorization:** allow only the ingress gateway to call payment, and only payment to call risk/ledger.
8. **Observability:** inspect topology, RED metrics, access logs and traces.
9. **Troubleshooting:** apply intentionally broken resources and diagnose with `istioctl` and `kubectl`.

## Important commands

```bash
kubectl get pods -n payments
istioctl proxy-status
istioctl analyze -A
istioctl proxy-config routes deploy/payment-v1 -n payments
istioctl proxy-config clusters deploy/payment-v1 -n payments
istioctl x describe service payment-api -n payments
kubectl logs -n payments deploy/payment-v1 -c istio-proxy --tail=100
```

Read [docs/INSTALLATION.md](docs/INSTALLATION.md) for detailed setup and [docs/INTERVIEW-QA.md](docs/INTERVIEW-QA.md) for interview preparation.
