#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require kubectl

KIND="${1:-}"
NAME="${2:-}"
NS="${3:-$NAMESPACE}"
FINALIZER_TO_REMOVE="${4:-}"

if [[ -z "$KIND" || -z "$NAME" || -z "$FINALIZER_TO_REMOVE" ]]; then
  cat >&2 <<'USAGE'
Usage:
  ./scripts/14-resolve-stuck-finalizer.sh KIND NAME NAMESPACE FINALIZER

Example:
  ./scripts/14-resolve-stuck-finalizer.sh paymentcleanup txn-stuck-demo payments interview.demo/manual-cleanup
USAGE
  exit 2
fi

warn "Removing a finalizer can orphan cloud volumes, load balancers, DNS records, or audit work."
info "Inspecting current deletion state"
kubectl get "$KIND" "$NAME" -n "$NS" -o custom-columns='NAME:.metadata.name,DELETION-TIMESTAMP:.metadata.deletionTimestamp,FINALIZERS:.metadata.finalizers'

CURRENT="$(kubectl get "$KIND" "$NAME" -n "$NS" -o jsonpath='{.metadata.finalizers}')"
if [[ "$CURRENT" != *"$FINALIZER_TO_REMOVE"* ]]; then
  fail "Finalizer $FINALIZER_TO_REMOVE is not present on $KIND/$NAME"
fi

info "Removing only the requested finalizer and preserving any others"
kubectl get "$KIND" "$NAME" -n "$NS" -o json \
  | python -c 'import json,sys; target=sys.argv[1]; obj=json.load(sys.stdin); obj["metadata"]["finalizers"]=[f for f in obj["metadata"].get("finalizers",[]) if f != target]; print(json.dumps({"metadata":{"finalizers":obj["metadata"]["finalizers"]}}))' "$FINALIZER_TO_REMOVE" \
  | kubectl patch "$KIND" "$NAME" -n "$NS" --type=merge --patch-file=/dev/stdin

info "Finalizer removed. The API server can complete deletion when no finalizers remain."
