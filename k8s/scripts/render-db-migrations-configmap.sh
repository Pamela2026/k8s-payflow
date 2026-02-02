#!/usr/bin/env bash
# #### Purpose ####
# #### Renders SQL migrations into a ConfigMap manifest for Kubernetes. ####
# #### Reads payflow-wallet/migrations and writes k8s/configmaps/db-migrations.yaml. ####
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
migrations_dir="$repo_root/payflow-wallet/migrations"
output_file="$repo_root/k8s/configmaps/db-migrations.yaml"
namespace="payflow"
configmap_name="payflow-db-migrations"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found in PATH" >&2
  exit 1
fi

if [ ! -d "$migrations_dir" ]; then
  echo "Migrations directory not found: $migrations_dir" >&2
  exit 1
fi

kubectl create configmap "$configmap_name" \
  --from-file="$migrations_dir" \
  -n "$namespace" \
  --dry-run=client -o yaml > "$output_file"

echo "Wrote $output_file"
