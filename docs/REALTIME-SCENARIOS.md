# Real-Time BFSI Scenarios

## 1. Canary payment release produces intermittent 503s

**Situation:** Payment v2 was deployed and 10% traffic enabled. Only v2 requests returned 503.

**Investigation:** Kiali showed errors only on the v2 edge. `istioctl proxy-config endpoints` showed no v2 endpoints. The DestinationRule expected `version: v2`, but the deployment label was `release: v2`.

**Resolution:** Corrected the workload label, verified endpoints, ran synthetic payments and gradually restored 10%, 25%, 50%, then 100% traffic.

**Interview value:** Shows separation of deployment from traffic routing and use of labels/subsets.

## 2. New default-deny policy blocks ledger calls

**Situation:** External payment calls reached payment-api, but payment returned `PENDING_LEDGER`.

**Investigation:** Payment proxy logs showed `RBAC: access denied` on ledger. The policy allowed the namespace but not the actual `payment-api` service account principal.

**Resolution:** Added the exact SPIFFE principal, tested from the payment identity, and used a staged policy rollout with dry-run/audit validation before enforcing in higher environments.

## 3. Latency increases after retries are added

**Situation:** A downstream service slowed from 200 ms to 2 seconds. A retry policy with three attempts caused request duration and downstream traffic to increase sharply.

**Investigation:** Prometheus showed higher request volume at the dependency than at ingress. Jaeger showed repeated attempts. Envoy access logs showed timeout response flags.

**Resolution:** Set a total timeout, smaller per-try timeout, limited retries to safe errors, added circuit breaking and rolled back the faulty dependency release.

**Lesson:** Retries require budgets; uncontrolled retries create retry storms.

## 4. Legacy workload fails after STRICT mTLS

**Situation:** Most services had sidecars, but an old batch client did not. After namespace-wide STRICT mTLS, its calls failed.

**Resolution:** Temporarily scoped PERMISSIVE mode to the specific destination port/workload, onboarded the legacy client into the mesh, verified telemetry showed no plaintext calls, then restored STRICT.

## 5. Trace is split into separate services

**Situation:** Jaeger displayed payment, risk and ledger as unrelated traces.

**Root cause:** The application created downstream HTTP calls without forwarding B3/W3C headers.

**Resolution:** Added trace-context propagation, regenerated traffic and confirmed one end-to-end trace.
