# Security Lab

## Stage 1 — Enforce mTLS

```bash
kubectl apply -f k8s/security/10-peer-authentication-strict.yaml
istioctl proxy-config secret deployment/payment-v1 -n payments
```

STRICT means the destination sidecar accepts only mutual-TLS mesh traffic. It prevents a plaintext workload from bypassing workload identity.

## Stage 2 — Apply default deny

Apply all rules together to avoid an unnecessary outage:

```bash
./scripts/08-apply-security.sh
```

Policy model:

```text
ingressgateway service account -> payment-api
payment-api service account     -> risk-api
payment-api service account     -> ledger-api
mesh-client service account     -> payment-api (lab test)
all other inbound calls         -> denied
```

## Test a permitted identity

```bash
kubectl exec -n payments deploy/mesh-client -c curl -- \
  curl -s http://payment-api:8080/pay?amount=100
```

## Test a plaintext legacy client

```bash
kubectl apply -f k8s/broken/03-plaintext-client.yaml
kubectl exec -n legacy-client legacy-curl -- \
  curl -v --max-time 5 http://payment-api.payments:8080/pay?amount=100
```

Expected: connection failure/reset because the caller has no Envoy sidecar and cannot establish Istio mTLS.

## Authentication versus authorization

- **PeerAuthentication** controls transport authentication for workload-to-workload connections.
- **RequestAuthentication** validates end-user JWT credentials when present.
- **AuthorizationPolicy** permits or denies requests based on workload identity, namespace, method, path, claims, IP and other attributes.
- mTLS authenticates a workload but does not by itself decide whether that workload is allowed to call a service.

## Production recommendations

- Start in PERMISSIVE during migration, measure plaintext callers, then move to STRICT.
- Use default-deny and explicit allows.
- Bind policies to service accounts and stable workload labels.
- Keep the ingress gateway in its own namespace and account.
- Apply NetworkPolicy as another layer; Istio policy does not replace L3/L4 network controls.
- Restrict access to control-plane/debug endpoints.
- Use revision-based Istio upgrades and verify proxies are on the intended revision.
