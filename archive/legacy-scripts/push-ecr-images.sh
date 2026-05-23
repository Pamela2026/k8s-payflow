#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-us-east-1}"
ACCOUNT_ID="${ACCOUNT_ID:-}"
IMAGE_TAG="${IMAGE_TAG:-}"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws not found in PATH" >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found in PATH" >&2
  exit 1
fi

if [[ -z "$ACCOUNT_ID" ]]; then
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
fi

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

services=(
  "payflow-wallet-api-gateway:v2"
  "payflow-wallet-auth-service:v2"
  "payflow-wallet-frontend:v3"
  "payflow-wallet-notification-service:v2"
  "payflow-wallet-transaction-service:v2"
  "payflow-wallet-wallet-service:v2"
)

aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

for img in "${services[@]}"; do
  name="${img%%:*}"
  tag="${img##*:}"
  if [[ -n "$IMAGE_TAG" ]]; then
    tag="$IMAGE_TAG"
  fi

  repo="$name"

  aws ecr describe-repositories --repository-names "$repo" --region "$REGION" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "$repo" --region "$REGION" >/dev/null

  docker pull "pamela001/$img"
  docker tag "pamela001/$img" "${ECR_REGISTRY}/${repo}:${tag}"
  docker push "${ECR_REGISTRY}/${repo}:${tag}"
done

echo "Pushed images to ${ECR_REGISTRY}"
