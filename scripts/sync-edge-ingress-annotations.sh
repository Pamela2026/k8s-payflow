#!/usr/bin/env bash
set -euo pipefail

ENV="${ENV:-dev}"
EDGE_DIR="${EDGE_DIR:-terraform/environments/${ENV}/edge}"
PLATFORM_INFRA_DIR="${PLATFORM_INFRA_DIR:-terraform/environments/${ENV}/platform/infra}"
KUSTOMIZATION_FILE="${KUSTOMIZATION_FILE:-overlays/${ENV}/kustomization.yaml}"
MODE="${MODE:-https}" # https | http

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform not found in PATH" >&2
  exit 1
fi

if [[ ! -f "$KUSTOMIZATION_FILE" ]]; then
  echo "kustomization.yaml not found: $KUSTOMIZATION_FILE" >&2
  exit 1
fi

WAF_ARN="$(terraform -chdir="$PLATFORM_INFRA_DIR" output -raw waf_web_acl_arn || true)"
ACM_ARN="$(terraform -chdir="$PLATFORM_INFRA_DIR" output -raw alb_certificate_arn || true)"

if [[ -z "${WAF_ARN}" ]]; then
  echo "WAF ARN not found in platform/infra outputs (waf_web_acl_arn)." >&2
  exit 1
fi

LISTEN_PORTS='[{"HTTP":80},{"HTTPS":443}]'
SSL_REDIRECT='443'

if [[ "${MODE}" == "http" ]]; then
  LISTEN_PORTS='[{"HTTP":80}]'
  SSL_REDIRECT=''
  ACM_ARN=''
fi

if [[ "${MODE}" == "https" && -z "${ACM_ARN}" ]]; then
  echo "ACM ARN not found in platform/infra outputs (alb_certificate_arn)." >&2
  exit 1
fi

perl -0777 -i -pe "s/WAF_WEB_ACL_ARN=.*/WAF_WEB_ACL_ARN=${WAF_ARN}/" "$KUSTOMIZATION_FILE"
perl -0777 -i -pe "s/ALB_LISTEN_PORTS=.*/ALB_LISTEN_PORTS=${LISTEN_PORTS}/" "$KUSTOMIZATION_FILE"
perl -0777 -i -pe "s/ALB_SSL_REDIRECT=.*/ALB_SSL_REDIRECT=${SSL_REDIRECT}/" "$KUSTOMIZATION_FILE"
perl -0777 -i -pe "s#ALB_CERT_ARN=.*#ALB_CERT_ARN=${ACM_ARN}#" "$KUSTOMIZATION_FILE"

echo "Updated ${KUSTOMIZATION_FILE} with WAF and ACM annotations."