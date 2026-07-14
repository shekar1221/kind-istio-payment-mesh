# Istio Troubleshooting Runbook

Use the sequence below instead of checking random components.

## 1. Confirm the Kubernetes application layer

```bash
kubectl get pods,svc,endpointslices -n payments
kubectl describe pod -n payments <pod>
kubectl logs -n payments <pod> -c payment-api
```

Questions:

- Is the pod Ready?
- Does the Service selector match pod labels?
- Does the Service have endpoints?
- Is `targetPort` correct and named `http`?

## 2. Confirm sidecar injection

```bash
kubectl get pod -n payments -o jsonpath='{range .items[*]}{.metadata.name}{" containers="}{.spec.containers[*].name}{"\n"}{end}'
istioctl x check-inject -n payments deploy/payment-v1
```

A newly created injected application pod normally shows `2/2` Ready.

## 3. Confirm proxy synchronization

```bash
istioctl proxy-status
```

`SYNCED` is expected for CDS, LDS, EDS and RDS. A stale proxy may not have received current routes or endpoints.

## 4. Validate configuration

```bash
istioctl analyze -A
kubectl get virtualservice,destinationrule,gateway -n payments -o yaml
```

## 5. Inspect the actual Envoy configuration

```bash
istioctl proxy-config routes deploy/payment-v1 -n payments
istioctl proxy-config clusters deploy/payment-v1 -n payments
istioctl proxy-config endpoints deploy/payment-v1 -n payments
istioctl proxy-config listeners deploy/payment-v1 -n payments
```

## 6. Check security

```bash
kubectl get peerauthentication,authorizationpolicy -n payments -o yaml
istioctl proxy-config secret deployment/payment-v1 -n payments
```

- HTTP 403 with `RBAC: access denied` usually indicates AuthorizationPolicy.
- Connection reset under STRICT mTLS often indicates a caller without a sidecar or an incompatible TLS DestinationRule.

## Scenario A — HTTP 503, no healthy upstream

```bash
kubectl apply -f k8s/broken/01-wrong-subset.yaml
curl -i http://localhost:8080/pay?amount=100
istioctl proxy-config endpoints deploy/istio-ingressgateway -n istio-system | grep payment
```

Root cause: subset label `production-v1-does-not-exist` selects no endpoints.

Fix:

```bash
kubectl apply -f k8s/traffic/01-destination-rules.yaml
```

## Scenario B — Header rule never works

```bash
kubectl apply -f k8s/broken/02-bad-virtualservice-order.yaml
istioctl analyze -A
```

Root cause: VirtualService HTTP rules are evaluated in order. A catch-all route placed first makes later matches unreachable.

Fix:

```bash
kubectl apply -f k8s/traffic/30-virtualservice-header.yaml
```

## Scenario C — 404 from ingress gateway

Checks:

```bash
kubectl get gateway,virtualservice -n payments
istioctl proxy-config routes deploy/istio-ingressgateway -n istio-system
```

Typical causes: host mismatch, gateway reference mismatch, wrong URI match, or request reached a different ingress endpoint.

## Scenario D — Application latency after release

1. Compare v1/v2 duration and error metrics in Grafana.
2. Route only a test header to v2.
3. Inspect Jaeger critical path.
4. Check retries multiplying downstream load.
5. Check Envoy `upstream_rq_pending_overflow`, connection-pool limits and response flags.
6. Roll traffic back to v1 by applying the baseline VirtualService; deployment rollback is not required merely to change traffic.

## Collect a diagnostic file

```bash
./scripts/09-diagnose.sh
```


# Scenario: custom resource stuck in Terminating

## Symptom

`kubectl delete` was accepted, but the object remains and has a `deletionTimestamp`.

## Diagnosis

```bash
kubectl get paymentcleanup txn-stuck-demo -n payments -o yaml
kubectl get events -n payments --sort-by=.lastTimestamp
kubectl logs -n payments deploy/payment-finalizer-controller --tail=200
kubectl auth can-i patch paymentcleanups.payments.example.com \
  --as=system:serviceaccount:payments:payment-finalizer-controller -n payments
```

Check the exact finalizer key and find the owning controller. Confirm controller health, RBAC, external API connectivity, credentials and whether cleanup is idempotent.

## Safe resolution

Restore the responsible controller and let it reconcile whenever possible. If the finalizer is proven stale and external cleanup is independently complete, remove only that key with `scripts/14-resolve-stuck-finalizer.sh`. Do not blindly patch every finalizer to an empty list because this can orphan infrastructure or audit work.
