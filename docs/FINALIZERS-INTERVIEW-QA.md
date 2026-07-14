# Kubernetes Finalizers Interview Questions and Answers

## 1. What is a Kubernetes finalizer?

A finalizer is a qualified string in `metadata.finalizers` that prevents the API server from completing deletion until a responsible controller finishes required cleanup and removes that string.

## 2. Is a finalizer a hook that Kubernetes executes?

No. It is only a coordination key. A controller watches the resource, sees `deletionTimestamp`, runs cleanup logic and patches the object to remove its own finalizer.

## 3. What happens when I delete an object that has a finalizer?

The API server sets `metadata.deletionTimestamp`, returns the object in a terminating state and blocks final removal. The object disappears only after all finalizers have been removed.

## 4. Can a user cancel deletion by removing `deletionTimestamp`?

No. `deletionTimestamp` is managed by the API server and cannot be cleared to restore the object. The controller should finish finalization, and a new object should be created if the desired state is needed again.

## 5. Why should custom finalizer names be qualified?

A domain-qualified key such as `payments.example.com/archive` reduces name collisions and makes controller ownership clear. It indicates which platform or operator is responsible.

## 6. Give a real production use case.

A cloud load-balancer controller may need to delete the provider-side load balancer before allowing the Kubernetes Service to disappear. Otherwise chargeable or security-sensitive infrastructure could remain orphaned.

## 7. How did you demonstrate finalizers in this project?

I created a `PaymentCleanup` CRD and a controller. The controller adds `payments.example.com/archive`. On deletion it creates audit evidence in a ConfigMap, updates status, removes only its finalizer and lets Kubernetes complete deletion. I also added a deliberately stale finalizer to demonstrate a stuck terminating resource and safe recovery.

## 8. What makes finalizer cleanup reliable?

The cleanup must be idempotent. The controller can restart or receive duplicate reconciliation events, so repeating cleanup should produce the same safe result rather than creating duplicate external actions.

## 9. Why might a resource stay in Terminating?

The controller may be down, lack RBAC, fail on an unavailable external API, encounter a code error, lose credentials, or no longer exist. The finalizer remains because cleanup has not been acknowledged.

## 10. How do you troubleshoot a stuck finalizer?

Inspect `deletionTimestamp` and `metadata.finalizers`, identify the owning controller, check its pods, logs, events and RBAC, then verify the external dependency and cleanup status. Restore or fix the controller first. Remove the finalizer manually only after cleanup is independently confirmed.

## 11. Why is blindly patching `finalizers: []` dangerous?

It can skip required cleanup and orphan cloud disks, load balancers, DNS records, database users, certificates or business records. It also removes finalizers owned by other controllers.

## 12. How do you remove only one stale finalizer?

Read the current list, preserve all other values, remove only the confirmed stale key and patch the updated list. In the lab, `14-resolve-stuck-finalizer.sh` performs this targeted removal.

## 13. Finalizer versus ownerReference?

A finalizer blocks deletion until cleanup is complete. An ownerReference expresses object ownership so Kubernetes garbage collection can remove dependents. They are complementary: an owner can have dependents and also need external cleanup.

## 14. Finalizer versus `preStop` hook?

A `preStop` hook runs inside a pod before the container terminates. A finalizer coordinates deletion of a Kubernetes API object and may wait for external cleanup. A pod can terminate even while a different resource remains blocked by a finalizer.

## 15. Finalizer versus `terminationGracePeriodSeconds`?

The grace period gives a pod process time to shut down after SIGTERM. It does not guarantee deletion of external resources and does not replace a controller finalizer.

## 16. Can finalizers be used on built-in and custom resources?

Yes. Metadata supports finalizers on Kubernetes objects. They are most commonly managed by controllers that understand the resource and its external side effects.

## 17. Should an application team manually add finalizers to Pods?

Usually no. Pod termination is better handled through readiness changes, `preStop`, graceful shutdown, PodDisruptionBudgets and controller behavior. A custom Pod finalizer requires a highly reliable controller and can easily leave Pods stuck.

## 18. What RBAC does a finalizer controller need?

At minimum, it needs get/list/watch and patch or update access to the resource, often access to the status subresource, plus permissions for any Kubernetes objects it creates or deletes during cleanup. Permissions should be namespace-scoped where possible.

## 19. Why update status during finalization?

Status conditions such as `Finalizing`, `CleanupFailed` and `CleanupComplete` improve troubleshooting. They expose the current phase, last error and observed generation rather than forcing operators to infer everything from logs.

## 20. What if cleanup takes several minutes?

Keep the finalizer, report progress through status, retry with backoff and expose metrics and alerts. The reconcile loop must not block all resources while waiting; it should persist state and return so other objects continue processing.

## 21. What if the external API is temporarily unavailable?

Do not remove the finalizer. Record the error, retry with exponential backoff and alert after an SLO threshold. If the outage becomes prolonged, follow a reviewed manual-cleanup and override runbook.

## 22. How do you avoid an infinite finalization loop?

Make cleanup idempotent, classify retryable versus permanent errors, record attempts and conditions, validate required fields and provide a controlled operator override. Alerts should detect objects whose deletion age exceeds a threshold.

## 23. Can a finalizer controller remove another controller's finalizer?

It should not. Each controller owns and removes only its own key. Removing another key violates ownership and may bypass work that the other controller still needs to complete.

## 24. How do finalizers relate to foreground deletion?

Foreground cascading deletion uses a system finalization mechanism to keep an owner visible until blocking dependents are deleted. A custom finalizer is controller-specific cleanup, often for external state.

## 25. Why can a namespace remain Terminating?

The namespace controller may still discover remaining resources, custom resources may have finalizers, an aggregated API may be unavailable, or webhooks/controllers may prevent cleanup. Diagnose discovery and resource deletion before forcing the namespace finalize endpoint.

## 26. What metrics would you expose for a finalizer controller?

Useful metrics include reconcile count, reconcile errors, cleanup duration, retry count, active finalizations, objects older than a threshold, external API failures and manual overrides.

## 27. How would you make the lab controller production-grade?

I would use controller-runtime or client-go informers, work queues, leader election, optimistic concurrency retries, structured status conditions, metrics, health probes, tracing, secure secret handling, high availability and tests for idempotency and failure recovery.

## 28. Does Istio replace finalizers?

No. Istio controls service traffic, identity, policy and telemetry. Finalizers control Kubernetes object deletion. Istio proxy draining may help finish active requests during pod termination, but it does not clean external cloud or business resources.

## 29. Give a BFSI incident scenario involving finalizers.

A payment tenant deletion remained Terminating because the reconciliation service could not reach the audit archive. I checked the finalizer owner, controller logs, RBAC and archive endpoint, restored connectivity and let the idempotent cleanup finish. I did not clear the finalizer because that would have removed the tenant object without preserving required audit evidence.

## 30. Give a two-minute interview explanation.

Finalizers are API deletion coordination, not executable hooks. When an object with a finalizer is deleted, Kubernetes sets `deletionTimestamp` but keeps the object. The owning controller performs idempotent cleanup, such as deleting a cloud load balancer or archiving payment evidence, and removes only its key. In my Kind project, a custom `PaymentCleanup` controller creates an audit ConfigMap before deletion. I also simulate a stale finalizer, troubleshoot controller health and RBAC, and use a targeted emergency removal only after verifying cleanup. This demonstrates controller reconciliation, CRDs, RBAC, lifecycle management and production-safe operations.
