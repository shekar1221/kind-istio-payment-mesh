# Istio Service Mesh Interview Questions and Answers

## 1. What problem does Istio solve?

Istio adds a consistent networking layer for service-to-service traffic. Using Envoy proxies, it provides traffic routing, mTLS identity, authorization, retries, timeouts, telemetry and policy without implementing each feature separately in every application language.

## 2. Explain Istio control plane and data plane.

Istiod is the control plane. It watches cluster resources, builds configuration, distributes xDS to proxies and supports certificate issuance. Envoy sidecars and gateways form the data plane; they process live requests. Application traffic does not flow through Istiod.

## 3. What happens during automatic sidecar injection?

A mutating admission webhook intercepts pod creation in a labelled namespace and modifies the Pod spec. It adds the `istio-proxy` container, init/network setup, projected identity token, volumes and annotations. Existing pods are not changed; they must be recreated.

## 4. Why does a pod show 2/2 Ready?

One container is the application and the second is the Envoy sidecar. Both must pass readiness before the pod is fully Ready.

## 5. VirtualService versus DestinationRule?

VirtualService decides how to match and route a request: host, path, headers, weights, retries, timeouts and faults. DestinationRule defines policies for the selected destination: subsets, load balancing, connection pools, outlier detection and TLS.

## 6. How do canary deployments work in Istio?

Deploy v1 and v2 concurrently with distinct version labels. Define subsets in a DestinationRule, then set weights in a VirtualService. Traffic percentage is independent of replica count, so teams can change exposure without redeploying workloads.

## 7. Kubernetes Service already load-balances. Why use Istio?

A Kubernetes Service provides stable discovery and basic endpoint load balancing. Istio adds application-aware L7 routing, version subsets, header rules, retries, timeouts, faults, identity, authorization and detailed telemetry.

## 8. What is mTLS in Istio?

Each sidecar receives a short-lived workload certificate associated with its service-account identity. Source and destination proxies authenticate each other and encrypt service traffic. In STRICT mode, the destination accepts only mTLS mesh traffic.

## 9. PERMISSIVE versus STRICT PeerAuthentication?

PERMISSIVE accepts both plaintext and mTLS, useful during gradual onboarding. STRICT accepts only mTLS and should be the final posture after confirming all legitimate callers participate in the mesh.

## 10. Does mTLS authorize access?

No. mTLS authenticates the caller identity and encrypts transport. AuthorizationPolicy decides whether that authenticated identity may call a workload, method or path.

## 11. How is workload identity represented?

By a SPIFFE-style principal such as `cluster.local/ns/payments/sa/payment-api`, derived from trust domain, namespace and Kubernetes service account.

## 12. What is the safest authorization model?

Default deny followed by explicit allow rules. Scope policies carefully to workloads and service-account principals, validate in lower environments and avoid broad namespace-wide allows when a specific identity is possible.

## 13. How do retries become dangerous?

Retries multiply traffic during an outage and can overload an already unhealthy dependency. Use a bounded total timeout, small attempt count, appropriate retry conditions, circuit breaking, idempotency and an overall retry budget.

## 14. Explain circuit breaking and outlier detection.

Connection-pool limits protect a destination from excessive concurrent connections or pending requests. Outlier detection observes failures and temporarily ejects unhealthy endpoints. It is passive health-based load balancing, not a replacement for Kubernetes readiness probes.

## 15. Readiness probe versus outlier detection?

Readiness removes an endpoint from Kubernetes service discovery when the local workload is not ready. Outlier detection lets Envoy temporarily avoid an endpoint based on observed request failures. Both can work together at different layers.

## 16. What causes `503 no healthy upstream`?

Common causes are an empty Service endpoint set, a DestinationRule subset matching no pods, all endpoints ejected/unready, wrong port, or stale proxy endpoint discovery. Check endpoints, labels, `istioctl proxy-status` and `proxy-config endpoints`.

## 17. What causes an ingress 404?

Usually no Gateway/VirtualService route matches the request host/path, the VirtualService references another gateway, or the request reached the wrong gateway. Inspect ingress proxy routes and compare the actual Host header.

## 18. How do you troubleshoot an Istio issue systematically?

First validate pods, Services and endpoints. Then sidecar injection, proxy sync, `istioctl analyze`, actual Envoy routes/clusters/endpoints, authorization/mTLS, and finally access logs, metrics and traces. This prevents blaming the mesh for a basic selector or application problem.

## 19. What does `istioctl proxy-status` show?

Whether each proxy is connected to Istiod and synchronized for clusters, listeners, endpoints and routes. A proxy with stale or not-sent configuration may behave differently from the declared YAML.

## 20. Why inspect `proxy-config`?

Kubernetes/Istio YAML is desired state. `proxy-config` shows what Envoy actually received. It confirms whether a route, cluster or endpoint exists in the proxy handling the failing request.

## 21. How does distributed tracing work?

Envoy creates spans and sends them to a configured provider. Applications must propagate trace headers on downstream calls; otherwise each service appears as a separate trace. Sampling controls how many requests are recorded.

## 22. What is Kiali used for?

Kiali visualizes service topology, traffic rates, errors, latency, mTLS state and configuration validation. It depends mainly on Prometheus metrics and should be treated as an operational view, not the sole source of truth.

## 23. Why are Istio sample add-ons unsuitable for production?

They use simple demo manifests with limited security, storage, scaling and availability. Production should deploy maintained operators/Helm charts, persistent storage, authentication, resource sizing, backups and proper retention.

## 24. How would you upgrade Istio safely?

Use revision-based installation: install a new control-plane revision, label a test namespace/workload to the new revision, restart selected pods, validate telemetry and policies, migrate gradually, then remove the old revision after all proxies have moved.

## 25. What happens if Istiod goes down?

Existing proxies continue using their last accepted configuration, so current traffic can continue. New proxies may not obtain configuration/certificates, and config changes will not propagate. Recovery urgency depends on certificate lifetime and deployment activity.

## 26. Ingress controller versus Istio ingress gateway?

Both expose HTTP traffic, but an Istio gateway is an Envoy proxy integrated with mesh routing, identity, policy and telemetry. A traditional ingress controller may be simpler when advanced service-mesh features are unnecessary. Some enterprises use an external API gateway/WAF before an Istio ingress gateway.

## 27. Sidecar mode versus ambient mode?

Sidecar mode places Envoy next to each workload and provides mature L7 control. Ambient mode moves baseline L4 security/connectivity to node-level ztunnel and optionally uses waypoint proxies for L7 features. This project uses sidecars because they make proxy behavior and interview concepts explicit.

## 28. How would this map to EKS?

Replace Kind with EKS, use a supported Istio installation method and production profiles, expose ingress through an AWS NLB/ALB architecture as designed, integrate ACM/WAF/API Gateway where required, use managed Prometheus/Grafana or enterprise telemetry, define PodDisruptionBudgets and autoscaling, and operate upgrades through revisions and GitOps.

## 29. Give a real canary rollback answer.

I keep v1 and v2 running, change only the VirtualService weights, and watch error rate, P95/P99 latency and business success metrics by version. If thresholds breach, I route 100% back to v1 immediately, preserve v2 for logs/traces, fix it, rerun tests and resume gradual traffic.

## 30. How do you explain this project in two minutes?

I created a three-node Kind cluster and installed Istio in sidecar mode. I deployed a payment API with v1/v2 plus risk and ledger dependencies. I used Gateway, VirtualService and DestinationRule for baseline, canary, header routing, faults and mirroring. I enforced STRICT mTLS and service-account-based default-deny authorization. I added Prometheus, Grafana, Kiali and Jaeger, propagated trace headers, and built troubleshooting cases for empty subsets, route ordering, RBAC denial and plaintext clients.


# Related Kubernetes lifecycle questions

## 31. What is a Kubernetes finalizer?

A finalizer is a qualified key in object metadata that blocks final API deletion until its owning controller completes cleanup and removes that key. Kubernetes sets `deletionTimestamp`; it does not execute the finalizer itself.

## 32. How does the finalizers lab complement the Istio lab?

Istio demonstrates runtime traffic, identity and telemetry. The finalizers module demonstrates Kubernetes API lifecycle and controller reconciliation. The custom `PaymentCleanup` controller archives simulated payment evidence before allowing resource deletion.

## 33. Finalizer versus Istio proxy drain?

Proxy drain helps Envoy finish active network requests during pod termination. A finalizer controls deletion of an API object and can coordinate external cleanup. They solve different problems and can both participate in a production shutdown workflow.

For the complete finalizers set, see `docs/FINALIZERS-INTERVIEW-QA.md`.
