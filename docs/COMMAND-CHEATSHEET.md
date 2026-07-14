# Command Cheat Sheet

## Inventory

```bash
kubectl get pods -A
kubectl get gateway,virtualservice,destinationrule -A
kubectl get peerauthentication,authorizationpolicy -A
```

## Injection

```bash
kubectl label namespace payments istio-injection=enabled --overwrite
kubectl rollout restart deployment -n payments
istioctl x check-inject -n payments deploy/payment-v1
```

## Diagnostics

```bash
istioctl analyze -A
istioctl proxy-status
istioctl x describe pod -n payments -l app=payment-api
istioctl proxy-config routes deploy/istio-ingressgateway -n istio-system
istioctl proxy-config clusters deploy/payment-v1 -n payments
istioctl proxy-config endpoints deploy/payment-v1 -n payments
istioctl proxy-config listeners deploy/payment-v1 -n payments
```

## Logs

```bash
kubectl logs -n payments deploy/payment-v1 -c payment-api --tail=100
kubectl logs -n payments deploy/payment-v1 -c istio-proxy --tail=100
kubectl logs -n istio-system deploy/istiod --tail=100
```

## Dashboards

```bash
istioctl dashboard kiali
istioctl dashboard grafana
istioctl dashboard jaeger
istioctl dashboard prometheus
```

## Security

```bash
istioctl proxy-config secret deployment/payment-v1 -n payments
kubectl get peerauthentication,authorizationpolicy -n payments -o yaml
```

## Roll back traffic

```bash
kubectl apply -f k8s/traffic/10-virtualservice-baseline.yaml
```


# Finalizers and deletion lifecycle

```bash
# List objects with finalizers
kubectl get paymentcleanups -n payments -o custom-columns='NAME:.metadata.name,DELETING:.metadata.deletionTimestamp,FINALIZERS:.metadata.finalizers'

# Inspect a resource
kubectl get paymentcleanup txn-2026-0001 -n payments -o yaml
kubectl describe paymentcleanup txn-2026-0001 -n payments

# Controller health and logs
kubectl get deploy,pod -n payments -l app.kubernetes.io/name=payment-finalizer-controller
kubectl logs -n payments deploy/payment-finalizer-controller -f

# Validate controller RBAC
kubectl auth can-i patch paymentcleanups.payments.example.com \
  --as=system:serviceaccount:payments:payment-finalizer-controller -n payments

# Delete while keeping the shell non-blocking
kubectl delete paymentcleanup txn-2026-0001 -n payments --wait=false

# Run the normal and stuck demos
./scripts/12-demo-finalizer.sh
./scripts/13-demo-stuck-finalizer.sh

# Targeted recovery after external cleanup is verified
./scripts/14-resolve-stuck-finalizer.sh \
  paymentcleanup txn-stuck-demo payments interview.demo/manual-cleanup
```
