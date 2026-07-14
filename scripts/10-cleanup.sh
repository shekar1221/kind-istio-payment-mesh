#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require kind
kind delete cluster --name "$CLUSTER_NAME"
