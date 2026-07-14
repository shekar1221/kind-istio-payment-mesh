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
