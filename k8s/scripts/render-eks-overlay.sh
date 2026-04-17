#!/usr/bin/env bash
# ============================================
# RENDER EKS OVERLAY (BASH)
# ============================================
# #### Renders the ALB ingress from Terraform outputs or flags. ####
# #### Writes overlays/<env>/alb-ingress.yaml. ####
set -euo pipefail

env="dev"
dns_dir=""
acm_arn=""
app_domain=""
api_domain=""
http_only="false"
waf_acl_arn=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) env="$2"; shift 2 ;;
    --dns-dir) dns_dir="$2"; shift 2 ;;
    --acm-arn) acm_arn="$2"; shift 2 ;;
    --app-domain) app_domain="$2"; shift 2 ;;
    --api-domain) api_domain="$2"; shift 2 ;;
    --http-only) http_only="true"; shift 1 ;;
    --waf-acl-arn) waf_acl_arn="$2"; shift 2 ;;
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

dns_json="$(get_outputs "$dns_dir" || true)"
if [[ "$http_only" != "true" ]]; then
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
fi

if [[ -z "$waf_acl_arn" ]]; then
  waf_acl_arn="$(get_value "$dns_json" "waf_web_acl_arn")"
  [[ -z "$waf_acl_arn" ]] && waf_acl_arn="$(get_value "$dns_json" "waf_acl_arn")"
fi

missing=()
if [[ "$http_only" != "true" ]]; then
  [[ -z "$acm_arn" ]] && missing+=("acm_certificate_arn")
  [[ -z "$app_domain" ]] && missing+=("app_domain")
  [[ -z "$api_domain" ]] && missing+=("api_domain")
fi

if [[ "${#missing[@]}" -gt 0 ]]; then
  echo "Missing required values: ${missing[*]}" >&2
  exit 1
fi

if [[ "$http_only" == "true" ]]; then
waf_annotation=""
if [[ -n "$waf_acl_arn" ]]; then
  waf_annotation="    alb.ingress.kubernetes.io/wafv2-acl-arn: $waf_acl_arn"
fi
cat > "$overlay_dir/alb-ingress.yaml" <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: payflow-alb
  namespace: payflow
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
${waf_annotation}
spec:
  ingressClassName: alb
  rules:
  - http:
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
EOF
else
waf_annotation=""
if [[ -n "$waf_acl_arn" ]]; then
  waf_annotation="    alb.ingress.kubernetes.io/wafv2-acl-arn: $waf_acl_arn"
fi
cat > "$overlay_dir/alb-ingress.yaml" <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: payflow-alb
  namespace: payflow
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/certificate-arn: $acm_arn
    alb.ingress.kubernetes.io/actions.ssl-redirect: '{"Type": "redirect", "RedirectConfig": {"Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'${waf_annotation}
    
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
fi

echo "Wrote $overlay_dir/alb-ingress.yaml"
