# Traffic Management Labs

Keep `scripts/port-forward-gateway.sh` running.

## Lab 1 — Baseline 100% v1

```bash
kubectl apply -f k8s/traffic/10-virtualservice-baseline.yaml
./scripts/06-test-baseline.sh
```

Explain in an interview: the Kubernetes Service selects both versions, but the Istio route sends traffic to the `v1` subset, whose labels select only v1 endpoints.

## Lab 2 — 80/20 canary

```bash
kubectl apply -f k8s/traffic/20-virtualservice-canary.yaml
for i in $(seq 1 30); do curl -s http://localhost:8080/pay?amount=100 | grep payment_version; done
```

The split is statistical. A small sample may not be exactly 80/20.

## Lab 3 — Header-based release

```bash
kubectl apply -f k8s/traffic/30-virtualservice-header.yaml
curl -s http://localhost:8080/pay?amount=100 | grep payment_version
curl -s -H 'x-release: v2' http://localhost:8080/pay?amount=100 | grep payment_version
```

Use cases: internal testers, premium customers, geography or controlled feature validation. Avoid using untrusted user-controlled headers without sanitization at the edge.

## Lab 4 — Delay and abort faults

```bash
kubectl apply -f k8s/traffic/40-virtualservice-fault.yaml
time curl -s -H 'x-chaos: delay' http://localhost:8080/pay?amount=100
curl -i -H 'x-chaos: abort' http://localhost:8080/pay?amount=100
```

Fault injection validates timeout, retry, alerting and user-experience behavior without changing the application.

## Lab 5 — Traffic mirroring

```bash
kubectl apply -f k8s/traffic/50-virtualservice-mirror.yaml
curl -s http://localhost:8080/pay?amount=100
kubectl logs -n payments deploy/payment-v2 -c payment-api --tail=20
```

The client receives v1's response; v2 receives an asynchronous copy. Do not mirror non-idempotent production writes without safeguards because shadow requests may create duplicate side effects.

## Reset

```bash
kubectl apply -f k8s/traffic/10-virtualservice-baseline.yaml
```

## VirtualService versus DestinationRule

- `VirtualService`: where a request should go and what routing behavior applies.
- `DestinationRule`: policies applied after a destination is chosen, including subsets, load balancing, connection pools, outlier detection and client TLS.
