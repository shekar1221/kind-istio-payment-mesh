#!/usr/bin/env python3
"""Minimal Kubernetes finalizer controller using only the Python standard library.

The controller watches PaymentCleanup custom resources in its namespace.
It adds payments.example.com/archive as a finalizer. During deletion it writes
an audit ConfigMap, updates status, and removes the finalizer so deletion can finish.
"""

from __future__ import annotations

import json
import logging
import os
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from typing import Any

API_HOST = os.environ.get("KUBERNETES_SERVICE_HOST", "kubernetes.default.svc")
API_PORT = os.environ.get("KUBERNETES_SERVICE_PORT_HTTPS", "443")
NAMESPACE_FILE = "/var/run/secrets/kubernetes.io/serviceaccount/namespace"
TOKEN_FILE = "/var/run/secrets/kubernetes.io/serviceaccount/token"
CA_FILE = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

GROUP = "payments.example.com"
VERSION = "v1alpha1"
PLURAL = "paymentcleanups"
FINALIZER = "payments.example.com/archive"
POLL_SECONDS = int(os.environ.get("POLL_SECONDS", "5"))

logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(message)s",
)
LOG = logging.getLogger("payment-finalizer-controller")


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read().strip()


NAMESPACE = os.environ.get("WATCH_NAMESPACE") or read_text(NAMESPACE_FILE)
TOKEN = read_text(TOKEN_FILE)
BASE_URL = f"https://{API_HOST}:{API_PORT}"
SSL_CONTEXT = ssl.create_default_context(cafile=CA_FILE)


def api_request(
    method: str,
    path: str,
    body: dict[str, Any] | None = None,
    content_type: str = "application/json",
) -> tuple[int, dict[str, Any] | None]:
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Accept": "application/json",
            "Content-Type": content_type,
        },
    )
    try:
        with urllib.request.urlopen(request, context=SSL_CONTEXT, timeout=15) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        if exc.code == 404:
            return exc.code, None
        raise RuntimeError(f"Kubernetes API {method} {path} failed: {exc.code} {raw}") from exc


def collection_path() -> str:
    return f"/apis/{GROUP}/{VERSION}/namespaces/{NAMESPACE}/{PLURAL}"


def object_path(name: str, suffix: str = "") -> str:
    safe_name = urllib.parse.quote(name, safe="")
    return f"{collection_path()}/{safe_name}{suffix}"


def patch_object(name: str, patch: dict[str, Any]) -> None:
    api_request(
        "PATCH",
        object_path(name),
        patch,
        "application/merge-patch+json",
    )


def patch_status(name: str, status: dict[str, Any]) -> None:
    api_request(
        "PATCH",
        object_path(name, "/status"),
        {"status": status},
        "application/merge-patch+json",
    )


def archive_configmap_name(resource_name: str) -> str:
    normalized = resource_name.lower().replace("_", "-")
    return f"payment-cleanup-{normalized}"[:63].rstrip("-")


def ensure_archive_configmap(resource: dict[str, Any]) -> str:
    metadata = resource.get("metadata", {})
    spec = resource.get("spec", {})
    name = archive_configmap_name(metadata["name"])
    path = f"/api/v1/namespaces/{NAMESPACE}/configmaps/{urllib.parse.quote(name, safe='')}"
    _, existing = api_request("GET", path)
    if existing:
        return name

    now = datetime.now(timezone.utc).isoformat()
    body = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {
            "name": name,
            "namespace": NAMESPACE,
            "labels": {
                "app.kubernetes.io/name": "payment-finalizer-controller",
                "payments.example.com/archive": "true",
            },
            "annotations": {
                "payments.example.com/source-uid": metadata.get("uid", "unknown"),
            },
        },
        "data": {
            "resourceName": metadata["name"],
            "transactionId": str(spec.get("transactionId", "unknown")),
            "archivePath": str(spec.get("archivePath", "not-specified")),
            "requestedBy": str(spec.get("requestedBy", "unknown")),
            "deletionTimestamp": str(metadata.get("deletionTimestamp", "unknown")),
            "cleanupCompletedAt": now,
            "result": "External payment audit cleanup simulated successfully",
        },
    }
    api_request("POST", f"/api/v1/namespaces/{NAMESPACE}/configmaps", body)
    return name


def reconcile(resource: dict[str, Any]) -> None:
    metadata = resource.get("metadata", {})
    name = metadata.get("name")
    if not name:
        return

    finalizers = list(metadata.get("finalizers") or [])
    deleting = metadata.get("deletionTimestamp") is not None

    if not deleting and FINALIZER not in finalizers:
        LOG.info("Adding finalizer %s to %s", FINALIZER, name)
        patch_object(name, {"metadata": {"finalizers": finalizers + [FINALIZER]}})
        patch_status(
            name,
            {
                "phase": "Active",
                "message": "Finalizer registered; waiting for deletion request",
                "observedGeneration": metadata.get("generation", 1),
            },
        )
        return

    if deleting and FINALIZER in finalizers:
        LOG.info("Deletion detected for %s; running cleanup", name)
        patch_status(
            name,
            {
                "phase": "Finalizing",
                "message": "Archiving payment cleanup evidence before deletion",
                "observedGeneration": metadata.get("generation", 1),
            },
        )
        archive_name = ensure_archive_configmap(resource)
        LOG.info("Cleanup complete for %s; archive ConfigMap=%s", name, archive_name)
        remaining = [item for item in finalizers if item != FINALIZER]
        patch_object(name, {"metadata": {"finalizers": remaining}})


def run_once() -> None:
    _, payload = api_request("GET", collection_path())
    for item in (payload or {}).get("items", []):
        try:
            reconcile(item)
        except Exception:  # keep reconciling other objects
            LOG.exception("Reconcile failed for %s", item.get("metadata", {}).get("name", "unknown"))


def main() -> None:
    LOG.info(
        "Starting controller namespace=%s resource=%s/%s finalizer=%s",
        NAMESPACE,
        GROUP,
        PLURAL,
        FINALIZER,
    )
    while True:
        try:
            run_once()
        except Exception:
            LOG.exception("List/reconcile cycle failed")
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
