#!/usr/bin/env bash
# ============================================
# INSTALL DATADOG LAB
# ============================================
# #### Installs Datadog into a separate namespace/release to avoid impacting existing monitoring stack. ####

set -euo pipefail

# ============================================
# INPUT VALIDATION
# ============================================
# #### Usage: ./k8s/scripts/install-datadog-lab.sh <DATADOG_API_KEY> <DATADOG_APP_KEY> ####
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <DATADOG_API_KEY> <DATADOG_APP_KEY>" >&2
  exit 1
fi

DD_API_KEY="$1"
DD_APP_KEY="$2"

# ============================================
# INSTALL SETTINGS
# ============================================
NAMESPACE="datadog-lab"
RELEASE="datadog-lab"
VALUES_FILE="k8s/helm-values/datadog/datadog-values.yaml"

# ============================================
# PRECHECKS
# ============================================
# #### Ensure required CLIs exist before running cluster changes. ####
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm is required"; exit 1; }

# ============================================
# NAMESPACE + SECRET
# ============================================
# #### Keep Datadog keys in a dedicated secret used by Helm values. ####
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

kubectl -n "$NAMESPACE" create secret generic datadog-keys \
  --from-literal=api-key="$DD_API_KEY" \
  --from-literal=app-key="$DD_APP_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# ============================================
# HELM INSTALL/UPGRADE
# ============================================
# #### Uses a distinct release name and namespace for safe parallel testing. ####
helm repo add datadog https://helm.datadoghq.com >/dev/null
helm repo update >/dev/null

helm upgrade --install "$RELEASE" datadog/datadog \
  --namespace "$NAMESPACE" \
  -f "$VALUES_FILE"

echo
echo "Datadog lab installed."
echo "Namespace: $NAMESPACE"
echo "Release:   $RELEASE"
