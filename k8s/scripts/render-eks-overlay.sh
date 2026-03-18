#!/usr/bin/env bash
# ============================================
# RENDER EKS OVERLAY (BASH)
# ============================================
# #### Renders ExternalName services + ALB ingress from Terraform outputs or flags. ####
# #### Writes overlays/<env>/externalname-services.yaml and overlays/<env>/alb-ingress.yaml. ####
set -euo pipefail

env="dev"
services_dir=""
dns_dir=""
rds_endpoint=""
redis_endpoint=""
rabbitmq_endpoint=""
acm_arn=""
app_domain=""
api_domain=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) env="$2"; shift 2 ;;
    --services-dir) services_dir="$2"; shift 2 ;;
    --dns-dir) dns_dir="$2"; shift 2 ;;
    --rds-endpoint) rds_endpoint="$2"; shift 2 ;;
    --redis-endpoint) redis_endpoint="$2"; shift 2 ;;
    --rabbitmq-endpoint) rabbitmq_endpoint="$2"; shift 2 ;;
    --acm-arn) acm_arn="$2"; shift 2 ;;
    --app-domain) app_domain="$2"; shift 2 ;;
    --api-domain) api_domain="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
overlay_dir="$repo_root/overlays/$env"

if [[ ! -d "$overlay_dir" ]]; then
  echo "Overlay not found: $overlay_dir" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found in PATH (required to parse terraform output -json)" >&2
  exit 1
fi

get_outputs() {
  local dir="$1"
  [[ -z "$dir" ]] && return 0
  [[ ! -d "$dir" ]] && { echo "Terraform dir not found: $dir" >&2; exit 1; }
  terraform -chdir="$dir" output -json
}

get_value() {
  local json="$1"
  local key="$2"
  echo "$json" | jq -r --arg k "$key" '.[$k].value // empty'
}

services_json="$(get_outputs "$services_dir" || true)"
dns_json="$(get_outputs "$dns_dir" || true)"

if [[ -z "$rds_endpoint" ]]; then
  rds_endpoint="$(get_value "$services_json" "rds_endpoint")"
  [[ -z "$rds_endpoint" ]] && rds_endpoint="$(get_value "$services_json" "db_endpoint")"
fi
if [[ -z "$redis_endpoint" ]]; then
  redis_endpoint="$(get_value "$services_json" "redis_endpoint")"
  [[ -z "$redis_endpoint" ]] && redis_endpoint="$(get_value "$services_json" "elasticache_endpoint")"
fi
if [[ -z "$rabbitmq_endpoint" ]]; then
  rabbitmq_endpoint="$(get_value "$services_json" "rabbitmq_endpoint")"
  [[ -z "$rabbitmq_endpoint" ]] && rabbitmq_endpoint="$(get_value "$services_json" "mq_endpoint")"
fi
if [[ -z "$acm_arn" ]]; then
  acm_arn="$(get_value "$dns_json" "acm_certificate_arn")"
  [[ -z "$acm_arn" ]] && acm_arn="$(get_value "$dns_json" "alb_acm_certificate_arn")"
fi
if [[ -z "$app_domain" ]]; then
  app_domain="$(get_value "$dns_json" "app_domain")"
  [[ -z "$app_domain" ]] && app_domain="$(get_value "$dns_json" "root_domain")"
fi
if [[ -z "$api_domain" ]]; then
  api_domain="$(get_value "$dns_json" "api_domain")"
fi

missing=()
[[ -z "$rds_endpoint" ]] && missing+=("rds_endpoint/db_endpoint")
[[ -z "$redis_endpoint" ]] && missing+=("redis_endpoint/elasticache_endpoint")
[[ -z "$rabbitmq_endpoint" ]] && missing+=("rabbitmq_endpoint/mq_endpoint")
[[ -z "$acm_arn" ]] && missing+=("acm_certificate_arn")
[[ -z "$app_domain" ]] && missing+=("app_domain")
[[ -z "$api_domain" ]] && missing+=("api_domain")

if [[ "${#missing[@]}" -gt 0 ]]; then
  echo "Missing required values: ${missing[*]}" >&2
  exit 1
fi

cat > "$overlay_dir/externalname-services.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: payflow
spec:
  type: ExternalName
  externalName: $rds_endpoint
---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: payflow
spec:
  type: ExternalName
  externalName: $redis_endpoint
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq-service
  namespace: payflow
spec:
  type: ExternalName
  externalName: $rabbitmq_endpoint
EOF

cat > "$overlay_dir/alb-ingress.yaml" <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: payflow-alb
  namespace: payflow
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/certificate-arn: $acm_arn
spec:
  ingressClassName: alb
  rules:
  - host: $app_domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 80
  - host: $api_domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 80
EOF

echo "Wrote $overlay_dir/externalname-services.yaml"
echo "Wrote $overlay_dir/alb-ingress.yaml"
