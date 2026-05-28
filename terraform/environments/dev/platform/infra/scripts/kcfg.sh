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
mkdir -p /home/ssm-user/.kube
export KUBECONFIG=/home/ssm-user/.kube/config
aws eks update-kubeconfig --name payflow-eks-dev --region us-east-1
