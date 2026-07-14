SHELL := /usr/bin/env bash

.PHONY: prereq cluster istio images deploy observability test diagnose finalizers finalizer-demo finalizer-stuck clean

prereq:
	./scripts/00-prereq-check.sh
cluster:
	./scripts/01-create-cluster.sh
istio:
	./scripts/02-install-istio.sh
images:
	./scripts/03-build-load-images.sh
deploy:
	./scripts/04-deploy-app.sh
observability:
	./scripts/05-deploy-observability.sh
test:
	./scripts/06-test-baseline.sh
diagnose:
	./scripts/09-diagnose.sh
finalizers:
	./scripts/11-deploy-finalizer-lab.sh
finalizer-demo:
	./scripts/12-demo-finalizer.sh
finalizer-stuck:
	./scripts/13-demo-stuck-finalizer.sh
clean:
	./scripts/10-cleanup.sh
