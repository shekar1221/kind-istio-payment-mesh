# Architecture

## Components

| Layer | Resource | Responsibility |
|---|---|---|
| Entry | `istio-ingressgateway` | Accepts north-south HTTP traffic |
| Routing | `Gateway` + `VirtualService` | Host/path matching, retries, timeout, traffic split and faults |
| Policy | `DestinationRule` | Version subsets and post-routing traffic policy |
| Workload | `payment-api` v1/v2 | Orchestrates the transaction |
| Dependency | `risk-api` | Approves or rejects based on amount |
| Dependency | `ledger-api` | Records successful payments |
| Security | `PeerAuthentication` | Enforces STRICT mTLS |
| Security | `AuthorizationPolicy` | Allows explicit service-account identities |
| Telemetry | Envoy + Telemetry API | Produces metrics, access logs and traces |

## Request flow

1. The client sends `GET /pay?amount=1200` to the ingress gateway.
2. The gateway's Envoy evaluates the `VirtualService`.
3. A destination subset is selected from the `DestinationRule`.
4. The request reaches the payment pod through its Envoy sidecar.
5. The payment application calls risk and ledger by Kubernetes Service DNS.
6. Outbound payment Envoy establishes mTLS with the destination Envoy.
7. Each proxy records request count, duration, response code and security identity.
8. Trace headers are forwarded by the application so Jaeger can join spans across services.

## Control plane and data plane

- **Istiod is the control plane.** It watches Kubernetes/Istio resources, converts them into Envoy configuration, distributes xDS updates and acts as the certificate authority/registration component.
- **Envoy sidecars and the ingress gateway are the data plane.** They handle actual requests, load balancing, TLS, policy checks and telemetry.
- Application traffic does not pass through Istiod. Loss of Istiod prevents new configuration/certificate updates, but existing proxies can continue with their last accepted configuration for a period.

## Why service accounts matter

Istio assigns workload identity using a SPIFFE-style principal:

```text
cluster.local/ns/<namespace>/sa/<service-account>
```

For example:

```text
cluster.local/ns/payments/sa/payment-api
```

Authorization policies in this project trust the service-account identity, not a changing Pod IP.
