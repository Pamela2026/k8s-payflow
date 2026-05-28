#!/usr/bin/env bash
set -e

REPO_DIR="/home/ssm-user/k8s-payflow"
REPO_URL="https://github.com/Pamela2026/k8s-payflow.git"

# Clone repository if needed, otherwise reuse the existing checkout.
if [ -d "$REPO_DIR" ]; then
    echo "Repository already exists, reusing checkout..."
    cd "$REPO_DIR"
else
    echo "Cloning repository..."
    git clone "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

# Update kubeconfig
export KUBECONFIG=/tmp/kubeconfig
aws eks update-kubeconfig --name payflow-eks-dev --region us-east-1

# Verify CRDs are established
kubectl wait --for=condition=Established crd/externalsecrets.external-secrets.io --timeout=120s
kubectl wait --for=condition=Established crd/clustersecretstores.external-secrets.io --timeout=120s

# Verify API resources are visible
kubectl api-resources --api-group=external-secrets.io
