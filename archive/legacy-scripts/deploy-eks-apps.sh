#!/usr/bin/env bash
set -euo pipefail

# Deploy Payflow app components on EKS with externalized infra/monitoring.
# Order: namespace/configs -> services -> migrations -> app services -> policies -> jobs -> ingress.

NAMESPACE="payflow"
TIMEOUT="${TIMEOUT:-600s}"
APPLY_DELAY="${APPLY_DELAY:-2}"

apply_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Skipping missing file: $file"
    return 0
  fi
  echo "Applying ${file}..."
  kubectl apply -f "$file"
  sleep "$APPLY_DELAY"
}

wait_rollout() {
  local kind="$1"
  local name="$2"
  echo "Waiting for $kind/$name..."
  case "$kind" in
    deploy|deployment)
      kubectl rollout status deploy/"$name" -n "$NAMESPACE" --timeout="$TIMEOUT"
      ;;
    sts|statefulset)
      kubectl rollout status sts/"$name" -n "$NAMESPACE" --timeout="$TIMEOUT"
      ;;
    job)
      kubectl wait --for=condition=complete job/"$name" -n "$NAMESPACE" --timeout="$TIMEOUT" \
        || { echo "Job $name did not complete."; \
             kubectl get pods -n "$NAMESPACE" -l job-name="$name" -o wide || true; \
             kubectl logs -n "$NAMESPACE" -l job-name="$name" --tail=200 || true; \
             kubectl describe job -n "$NAMESPACE" "$name" | tail -n 120 || true; \
             exit 1; }
      ;;
    *)
      echo "Unknown kind: $kind (use deploy|sts|job)"
      exit 1
      ;;
  esac
  echo "$kind/$name is ready"
}

echo "Starting PayFlow EKS app deployment..."

apply_file "k8s/namespace.yaml"

echo "Config and secrets..."
apply_file "k8s/configmaps/app-config.yaml"
apply_file "k8s/configmaps/db-migrations.yaml"

if [[ -f "k8s/secrets/db-secrets.yaml" ]] && grep -q "<base64-encoded" "k8s/secrets/db-secrets.yaml"; then
  echo "Skipping k8s/secrets/db-secrets.yaml (placeholders detected)."
else
  apply_file "k8s/secrets/db-secrets.yaml"
fi

echo "Services..."
apply_file "k8s/services/all-services.yaml"

echo "External services (Terraform-managed)..."
if [[ -d "overlays/dev" ]]; then
  kubectl apply -k overlays/dev || true
fi

echo "Running DB migrations..."
if kubectl get job payflow-db-migration -n "$NAMESPACE" >/dev/null 2>&1; then
  status="$(kubectl get job payflow-db-migration -n "$NAMESPACE" -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "")"
  if [[ "${status:-0}" == "1" ]]; then
    echo "Migration job already completed. Skipping."
  else
    echo "Migration job exists but not completed. Recreating..."
    kubectl delete job payflow-db-migration -n "$NAMESPACE" --ignore-not-found
    apply_file "k8s/jobs/db-migration-job.yaml"
    wait_rollout job payflow-db-migration
  fi
else
  apply_file "k8s/jobs/db-migration-job.yaml"
  wait_rollout job payflow-db-migration
fi

echo "Deploying Auth Service..."
apply_file "k8s/payflow-services/auth-service.yaml"
wait_rollout deploy auth-service

echo "Deploying Wallet Service..."
apply_file "k8s/payflow-services/wallet-service.yaml"
wait_rollout deploy wallet-service

echo "Deploying Transaction & Notification Services..."
apply_file "k8s/payflow-services/transaction-service.yaml"
apply_file "k8s/payflow-services/notification-service.yaml"
wait_rollout deploy transaction-service
wait_rollout deploy notification-service

echo "Deploying API Gateway..."
apply_file "k8s/payflow-services/api-gateway.yaml"
wait_rollout deploy api-gateway

echo "Deploying Frontend..."
apply_file "k8s/payflow-services/frontend.yaml"
wait_rollout deploy frontend

echo "Policies..."
apply_file "k8s/policies/limit-range.yaml"
apply_file "k8s/policies/resource-quotas.yaml"
apply_file "k8s/policies/pod-disruption-budgets.yaml"
apply_file "k8s/policies/network-policies.yaml"

echo "Autoscaling..."
apply_file "k8s/autoscaling/hpa.yaml"

echo "Background jobs..."
apply_file "k8s/jobs/transaction-timeout-handler.yaml"
apply_file "k8s/jobs/db-backup-cronjob.yaml"

echo "Ingress..."
apply_file "k8s/ingress/http-ingress.yaml"

echo "PayFlow EKS app deployment completed."
