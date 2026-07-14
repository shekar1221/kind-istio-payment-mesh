# Kubernetes Finalizers Lab

This module extends the Kind + Istio payment project with a small Kubernetes controller and a custom resource named `PaymentCleanup`.

The business scenario is a payment audit workflow. Before Kubernetes permanently removes a cleanup request, the controller must simulate archiving external evidence. It writes an audit `ConfigMap`, then removes its finalizer so deletion can finish.

## 1. What a finalizer does

A finalizer is a string stored in `metadata.finalizers`. It tells the Kubernetes API server that a controller still has cleanup work to perform.

When a delete request reaches an object that still has finalizers:

1. The API server accepts the request.
2. It sets `metadata.deletionTimestamp`.
3. The object remains visible and enters a terminating state.
4. A responsible controller notices the deletion timestamp.
5. The controller completes cleanup and removes only its own finalizer.
6. When the finalizer list is empty, the API server completes deletion.

A finalizer does **not** contain executable code. It is a coordination key. The controller implements the actual cleanup logic.

```text
kubectl delete PaymentCleanup
              |
              v
API server sets deletionTimestamp
              |
              v
Object remains because finalizer exists
              |
              v
Controller archives audit evidence
              |
              v
Controller removes payments.example.com/archive
              |
              v
API server deletes the object
```

## 2. Lab components

| Component | Purpose |
|---|---|
| `PaymentCleanup` CRD | Represents a payment transaction that needs controlled cleanup |
| `payment-finalizer-controller` | Adds the finalizer and handles deletion reconciliation |
| `payments.example.com/archive` | Qualified finalizer owned by this controller |
| Archive ConfigMap | Simulates an external audit archive that must survive CR deletion |
| Stuck resource | Demonstrates what happens when no controller removes a finalizer |

Files:

```text
apps/finalizer-controller/
  controller.py
  Dockerfile

k8s/finalizers/
  00-crd.yaml
  01-rbac.yaml
  02-controller.yaml
  10-sample-cleanup.yaml
  20-stuck-cleanup.yaml

scripts/
  11-deploy-finalizer-lab.sh
  12-demo-finalizer.sh
  13-demo-stuck-finalizer.sh
  14-resolve-stuck-finalizer.sh
```

## 3. Deploy the finalizer lab

The main Kind cluster, Istio and payment namespace must already exist.

```bash
./scripts/11-deploy-finalizer-lab.sh
```

Validate:

```bash
kubectl get crd paymentcleanups.payments.example.com
kubectl get deploy payment-finalizer-controller -n payments
kubectl auth can-i patch paymentcleanups.payments.example.com \
  --as=system:serviceaccount:payments:payment-finalizer-controller \
  -n payments
kubectl logs -n payments deploy/payment-finalizer-controller
```

The controller pod intentionally disables Istio sidecar injection. Its purpose is Kubernetes API reconciliation, not service-to-service traffic. The payment workloads remain in the mesh.

## 4. Normal deletion demo

Run:

```bash
./scripts/12-demo-finalizer.sh
```

Manual version:

```bash
kubectl apply -f k8s/finalizers/10-sample-cleanup.yaml
kubectl get paymentcleanup txn-2026-0001 -n payments -w
```

Check that the controller added its finalizer:

```bash
kubectl get paymentcleanup txn-2026-0001 -n payments \
  -o jsonpath='{.metadata.finalizers}{"\n"}'
```

Expected:

```text
["payments.example.com/archive"]
```

Delete without waiting:

```bash
kubectl delete paymentcleanup txn-2026-0001 -n payments --wait=false
```

Observe the transition:

```bash
kubectl get paymentcleanup txn-2026-0001 -n payments -o yaml
kubectl logs -n payments deploy/payment-finalizer-controller -f
```

The controller performs these actions:

1. Detects `deletionTimestamp`.
2. Sets the custom-resource status to `Finalizing`.
3. Creates `ConfigMap/payment-cleanup-txn-2026-0001` as audit evidence.
4. Removes only `payments.example.com/archive`.
5. Kubernetes deletes the `PaymentCleanup` object.

Inspect the archive:

```bash
kubectl get configmap payment-cleanup-txn-2026-0001 -n payments -o yaml
```

## 5. Stuck finalizer demo

Run:

```bash
./scripts/13-demo-stuck-finalizer.sh
```

The manifest has this finalizer:

```yaml
metadata:
  finalizers:
    - interview.demo/manual-cleanup
```

No controller owns that key, so deletion remains blocked.

```bash
kubectl get paymentcleanup txn-stuck-demo -n payments \
  -o custom-columns='NAME:.metadata.name,DELETING:.metadata.deletionTimestamp,FINALIZERS:.metadata.finalizers'
```

Expected behavior:

- `deletionTimestamp` is populated.
- The object is still returned by the API.
- Reapplying the original manifest does not cancel deletion.
- Kubernetes will not automatically guess that cleanup is safe.

## 6. Safe troubleshooting workflow

Do not start by clearing finalizers. First identify the controller and the unfinished cleanup.

```bash
kubectl get paymentcleanup txn-stuck-demo -n payments -o yaml
kubectl describe paymentcleanup txn-stuck-demo -n payments
kubectl get events -n payments --sort-by=.lastTimestamp
kubectl logs -n payments deploy/payment-finalizer-controller --tail=200
kubectl get deploy,pod -n payments
kubectl auth can-i patch paymentcleanups.payments.example.com \
  --as=system:serviceaccount:payments:payment-finalizer-controller \
  -n payments
```

Questions to answer before manual removal:

- Which controller owns the finalizer key?
- Is that controller running and leader-elected correctly?
- Does it have RBAC to read, patch and update the resource and status?
- Is an external cloud API, storage system, DNS service or database unavailable?
- Is cleanup idempotent, so a retry is safe?
- Could clearing the finalizer leak a load balancer, disk, DNS record or financial record?
- Is there evidence that manual cleanup has already completed?

## 7. Resolve the deliberate stuck example

Only after confirming cleanup is complete:

```bash
./scripts/14-resolve-stuck-finalizer.sh \
  paymentcleanup txn-stuck-demo payments interview.demo/manual-cleanup
```

The recovery script removes only the named finalizer and preserves any other controller finalizers.

Equivalent targeted procedure:

```bash
kubectl get paymentcleanup txn-stuck-demo -n payments -o json > /tmp/txn-stuck.json
# Review metadata.finalizers and external cleanup evidence first.
kubectl patch paymentcleanup txn-stuck-demo -n payments \
  --type=merge -p '{"metadata":{"finalizers":[]}}'
```

The direct empty-list patch is acceptable only for a controlled lab or a verified emergency. In production, prefer restoring the responsible controller or removing only the confirmed stale key.

## 8. Finalizer controller logic

The minimal controller uses a reconcile loop:

```python
if object is not deleting and my_finalizer is absent:
    add my_finalizer

if object has deletionTimestamp and my_finalizer is present:
    perform_idempotent_cleanup()
    remove_only_my_finalizer()
```

Production controller requirements:

- Use watch/informer caches instead of simple polling.
- Retry conflicts with resource-version-aware updates.
- Make cleanup idempotent.
- Record status conditions and actionable errors.
- Use exponential backoff and rate limiting.
- Use leader election with multiple replicas.
- Emit metrics for finalize duration, errors and stuck objects.
- Use least-privilege RBAC.
- Never remove another controller's finalizer.
- Define runbooks for external dependency outages.

## 9. Finalizer versus related Kubernetes mechanisms

| Mechanism | Purpose | Key difference |
|---|---|---|
| Finalizer | Block final API deletion until cleanup completes | Controller removes a key after cleanup |
| OwnerReference | Express ownership for garbage collection | Deletes dependents according to propagation rules |
| `preStop` hook | Run logic before a container process terminates | Container lifecycle hook, not API-object deletion coordination |
| Grace period | Give a pod time to exit | Time-based process shutdown behavior |
| Readiness probe | Remove an unhealthy endpoint from traffic | Does not control object deletion |
| Istio drain | Let Envoy finish active requests during pod termination | Traffic shutdown, not external-resource cleanup |

## 10. BFSI examples

### Payment audit archive

Before deleting a payment reconciliation object, archive transaction evidence and confirm the immutable record exists.

### External DNS cleanup

A controller creates DNS records for a service. Its finalizer deletes or transfers those records before the custom resource disappears.

### Cloud load balancer cleanup

A cloud controller finalizer ensures the provider-side load balancer is deleted before the Kubernetes Service object is removed.

### Storage cleanup

A storage controller uses finalizers to coordinate deletion of an external disk according to reclaim policy.

### Database user revocation

An operator revokes database credentials and validates that active sessions are terminated before removing a tenant object.

### Service-mesh configuration cleanup

An operator that creates external certificates, DNS entries or non-Kubernetes gateway configuration can use a finalizer. Ordinary Istio `VirtualService` and `DestinationRule` objects generally do not need a custom finalizer unless an operator created external state that Kubernetes garbage collection cannot remove.

## 11. Namespace stuck in Terminating

A namespace has its own finalization path. Start with discovery and controller health:

```bash
kubectl get namespace <name> -o yaml
kubectl api-resources --verbs=list --namespaced -o name \
  | xargs -n 1 kubectl get -n <name> --ignore-not-found
kubectl get apiservice | grep False || true
kubectl get events -n <name> --sort-by=.lastTimestamp
```

Typical causes:

- Remaining namespaced resources
- A custom resource whose controller is unavailable
- Unavailable aggregated API services
- Admission webhooks blocking updates
- Stale resource finalizers

Forcing namespace finalization through the `/finalize` subresource is a last resort. It can leave orphaned resources that become difficult to discover after the namespace object disappears.

## 12. Cleanup

Delete lab artifacts without deleting the whole Kind cluster:

```bash
kubectl delete -f k8s/finalizers/10-sample-cleanup.yaml --ignore-not-found
kubectl delete -f k8s/finalizers/20-stuck-cleanup.yaml --ignore-not-found --wait=false
kubectl delete -f k8s/finalizers/02-controller.yaml --ignore-not-found
kubectl delete -f k8s/finalizers/01-rbac.yaml --ignore-not-found
kubectl delete -f k8s/finalizers/00-crd.yaml --ignore-not-found
```

The CRD should be deleted last because deleting it requests deletion of every custom resource instance.

## Official references

- [Kubernetes finalizers](https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/)
- [Using finalizers to control deletion](https://kubernetes.io/blog/2021/05/14/using-finalizers-to-control-deletion/)
- [Kubernetes garbage collection](https://kubernetes.io/docs/concepts/architecture/garbage-collection/)
- [Custom resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [Extend the API with CustomResourceDefinitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)
