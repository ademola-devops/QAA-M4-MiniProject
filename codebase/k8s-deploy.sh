#!/bin/bash
set -euo pipefail
TAG="${1:-latest}"
cd "$(dirname "$0")"

# Backend first: nginx resolves the "backend" Service name at startup
sed "s|IMAGE_TAG|${TAG}|g" k8s/backend.yaml | kubectl apply -f -
kubectl rollout status deployment/backend --timeout=120s

sed "s|IMAGE_TAG|${TAG}|g" k8s/frontend.yaml | kubectl apply -f -
kubectl rollout status deployment/frontend --timeout=120s

kubectl get pods,svc
