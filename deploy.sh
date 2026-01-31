#!/bin/bash
set -euo pipefail

NAMESPACE="payflow"
MONITORING_NAMESPACE="monitoring"
TIMEOUT="${TIMEOUT:-600s}"
APPLY_DELAY="${APPLY_DELAY:-2}"

apply_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "⚠️  Skipping missing file: $file"
    return 0
  fi

  echo "🔧 Applying ${file}..."
  kubectl apply -f "$file"
  sleep "$APPLY_DELAY"
}

wait_rollout() {
  local kind="$1"   # deploy | sts | job
  local name="$2"

  echo "⏳ Waiting for $kind/$name to be ready..."

  case "$kind" in
    deploy|deployment)
      kubectl rollout status deploy/"$name" -n "$NAMESPACE" --timeout="$TIMEOUT"
      ;;
    sts|statefulset)
      kubectl rollout status sts/"$name" -n "$NAMESPACE" --timeout="$TIMEOUT"
      ;;
    job)
      kubectl wait --for=condition=complete job/"$name" -n "$NAMESPACE" --timeout="$TIMEOUT" \
        || { echo "❌ Job $name did not complete. Showing logs/events..."; \
             kubectl get pods -n "$NAMESPACE" -l job-name="$name" -o wide || true; \
             kubectl logs -n "$NAMESPACE" -l job-name="$name" --tail=200 || true; \
             kubectl describe job -n "$NAMESPACE" "$name" | tail -n 120 || true; \
             exit 1; }
      ;;
    *)
      echo "❌ Unknown kind: $kind (use deploy|sts|job)"
      exit 1
      ;;
  esac

  echo "✅ $kind/$name is ready"
}

echo "🚀 Starting PayFlow deployment (gentle mode)..."

apply_file "k8s/namespace.yaml"

echo "🗂️ Config and secrets..."
apply_file "k8s/configmaps/app-config.yaml"
apply_file "k8s/configmaps/db-migrations.yaml"

# Only apply secrets file if it exists AND doesn't contain placeholder text
if [[ -f "k8s/secrets/db-secrets.yaml" ]] && grep -q "<base64-encoded" "k8s/secrets/db-secrets.yaml"; then
  echo "⚠️  Skipping k8s/secrets/db-secrets.yaml (placeholders detected)."
else
  apply_file "k8s/secrets/db-secrets.yaml"
fi

echo "🔌 Services..."
apply_file "k8s/services/all-services.yaml"

echo "📦 Deploying infrastructure..."
apply_file "k8s/infrastructure/postgres.yaml"
apply_file "k8s/deployments/redis.yaml"
apply_file "k8s/infrastructure/rabbitmq.yaml"

echo "⏳ Waiting for infrastructure to be ready..."
wait_rollout sts postgres
wait_rollout deploy redis
wait_rollout sts rabbitmq

echo "🧭 Running DB migrations..."
# Your Flyway error shows you need baselineOnMigrate when schema already has tables.
# If you already fixed the job manifest, this will work. If not, it will fail and print logs.
if kubectl get job payflow-db-migration -n "$NAMESPACE" >/dev/null 2>&1; then
  status="$(kubectl get job payflow-db-migration -n "$NAMESPACE" -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "")"
  if [[ "${status:-0}" == "1" ]]; then
    echo "✅ Migration job already completed. Skipping."
  else
    echo "⚠️ Migration job exists but not completed. Recreating..."
    kubectl delete job payflow-db-migration -n "$NAMESPACE" --ignore-not-found
    apply_file "k8s/jobs/db-migration-job.yaml"
    wait_rollout job payflow-db-migration
  fi
else
  apply_file "k8s/jobs/db-migration-job.yaml"
  wait_rollout job payflow-db-migration
fi

echo "🔐 Deploying Auth Service..."
apply_file "k8s/deployments/auth-service.yaml"
wait_rollout deploy auth-service

echo "💰 Deploying Wallet Service..."
apply_file "k8s/deployments/wallet-service.yaml"
wait_rollout deploy wallet-service

echo "💳 Deploying Transaction & Notification Services..."
apply_file "k8s/deployments/transaction-service.yaml"
apply_file "k8s/deployments/notification-service.yaml"
wait_rollout deploy transaction-service
wait_rollout deploy notification-service

echo "🌐 Deploying API Gateway..."
apply_file "k8s/deployments/api-gateway.yaml"
wait_rollout deploy api-gateway

echo "🖥️ Deploying Frontend..."
apply_file "k8s/deployments/frontend.yaml"
wait_rollout deploy frontend

echo "🛡️ Policies..."
apply_file "k8s/policies/limit-range.yaml"
apply_file "k8s/policies/resource-quotas.yaml"
apply_file "k8s/policies/pod-disruption-budgets.yaml"
apply_file "k8s/policies/network-policies.yaml"

echo "📈 Deploying autoscaling..."
apply_file "k8s/autoscaling/hpa.yaml"

echo "🕒 Background jobs..."
apply_file "k8s/jobs/transaction-timeout-handler.yaml"
apply_file "k8s/jobs/db-migration-cronjob.yaml"


echo "🌐 Deploying ingress..."
apply_file "k8s/ingress/http-ingress.yaml"

echo "🌐 Deploying metrics-server..."
apply_file "k8s/infrastructure/metrics-server.yaml"

echo "📊 Deploying monitoring stack with Helm..."
if ! kubectl get namespace "$MONITORING_NAMESPACE" >/dev/null 2>&1; then
  kubectl create namespace "$MONITORING_NAMESPACE"
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo update >/dev/null

GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:payflow123}"
if [[ "$GRAFANA_ADMIN_PASSWORD" == "payflow123" ]]; then
  echo "⚠️  Grafana admin password is set to default (changeme). Set GRAFANA_ADMIN_PASSWORD to override."
fi

helm upgrade --install payflow-prometheus prometheus-community/prometheus \
  -n "$MONITORING_NAMESPACE" \
  -f k8s/helm-values/monitoring/prometheus-values.yaml \
  --create-namespace

helm upgrade --install payflow-loki grafana/loki \
  -n "$MONITORING_NAMESPACE" \
  -f k8s/helm-values/monitoring/loki-values.yaml \
  --create-namespace

helm upgrade --install payflow-promtail grafana/promtail \
  -n "$MONITORING_NAMESPACE" \
  -f k8s/helm-values/monitoring/promtail-values.yaml \
  --create-namespace

# Exporter credentials (only if secrets exist and are populated)
POSTGRES_EXPORTER_USER=""
POSTGRES_EXPORTER_PASSWORD=""
REDIS_EXPORTER_PASSWORD=""
RABBITMQ_EXPORTER_USER=""
RABBITMQ_EXPORTER_PASSWORD=""

if kubectl get secret payflow-secrets -n "$NAMESPACE" >/dev/null 2>&1; then
  POSTGRES_EXPORTER_USER="$(kubectl get secret payflow-secrets -n "$NAMESPACE" -o jsonpath='{.data.DB_USER}' 2>/dev/null | base64 -d || true)"
  POSTGRES_EXPORTER_PASSWORD="$(kubectl get secret payflow-secrets -n "$NAMESPACE" -o jsonpath='{.data.DB_PASSWORD}' 2>/dev/null | base64 -d || true)"
  REDIS_EXPORTER_PASSWORD="$(kubectl get secret payflow-secrets -n "$NAMESPACE" -o jsonpath='{.data.REDIS_PASSWORD}' 2>/dev/null | base64 -d || true)"
  RABBITMQ_EXPORTER_USER="$(kubectl get secret payflow-secrets -n "$NAMESPACE" -o jsonpath='{.data.RABBITMQ_DEFAULT_USER}' 2>/dev/null | base64 -d || true)"
  RABBITMQ_EXPORTER_PASSWORD="$(kubectl get secret payflow-secrets -n "$NAMESPACE" -o jsonpath='{.data.RABBITMQ_DEFAULT_PASS}' 2>/dev/null | base64 -d || true)"
fi

POSTGRES_EXPORTER_ARGS=()
if [[ -n "$POSTGRES_EXPORTER_USER" && -n "$POSTGRES_EXPORTER_PASSWORD" ]]; then
  POSTGRES_EXPORTER_ARGS+=(--set "config.datasource.user=${POSTGRES_EXPORTER_USER}")
  POSTGRES_EXPORTER_ARGS+=(--set "config.datasource.password=${POSTGRES_EXPORTER_PASSWORD}")
else
  echo "⚠️  Postgres exporter credentials missing; update payflow-secrets or set via Helm."
fi

REDIS_EXPORTER_ARGS=()
if [[ -n "$REDIS_EXPORTER_PASSWORD" ]]; then
  REDIS_EXPORTER_ARGS+=(--set "auth.enabled=true")
  REDIS_EXPORTER_ARGS+=(--set "auth.password=${REDIS_EXPORTER_PASSWORD}")
fi

RABBITMQ_EXPORTER_ARGS=()
if [[ -n "$RABBITMQ_EXPORTER_USER" && -n "$RABBITMQ_EXPORTER_PASSWORD" ]]; then
  RABBITMQ_EXPORTER_ARGS+=(--set "rabbitmq.user=${RABBITMQ_EXPORTER_USER}")
  RABBITMQ_EXPORTER_ARGS+=(--set "rabbitmq.password=${RABBITMQ_EXPORTER_PASSWORD}")
else
  echo "⚠️  RabbitMQ exporter credentials missing; update payflow-secrets or set via Helm."
fi

helm upgrade --install payflow-postgres-exporter prometheus-community/prometheus-postgres-exporter \
  -n "$NAMESPACE" \
  -f k8s/helm-values/monitoring/postgres-exporter-values.yaml \
  "${POSTGRES_EXPORTER_ARGS[@]}"

helm upgrade --install payflow-redis-exporter prometheus-community/prometheus-redis-exporter \
  -n "$NAMESPACE" \
  -f k8s/helm-values/monitoring/redis-exporter-values.yaml \
  "${REDIS_EXPORTER_ARGS[@]}"

helm upgrade --install payflow-rabbitmq-exporter prometheus-community/prometheus-rabbitmq-exporter \
  -n "$NAMESPACE" \
  -f k8s/helm-values/monitoring/rabbitmq-exporter-values.yaml \
  "${RABBITMQ_EXPORTER_ARGS[@]}"

helm upgrade --install payflow-grafana grafana/grafana \
  -n "$MONITORING_NAMESPACE" \
  -f k8s/helm-values/monitoring/grafana-values.yaml \
  --set adminPassword="$GRAFANA_ADMIN_PASSWORD" \
  --create-namespace

echo "✅ PayFlow deployment completed successfully!"
echo "🔍 Check status: kubectl get pods -n $NAMESPACE"
