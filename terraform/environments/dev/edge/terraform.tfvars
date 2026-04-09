region        = "us-east-1"
environment   = "dev"
project_name  = "payflow"
cluster_name  = "payflow-eks-dev"

enable_waf     = true
waf_rate_limit = 2000
waf_enable_common_rule_set     = true
waf_enable_bad_inputs_rule_set = true
waf_enable_sqli_rule_set       = true
waf_enable_rate_limit          = true

enable_cdn     = true
app_domain     = "computehub.online"
hosted_zone_id = "Z02373822JO7MP3G5ZLH"
ingress_name   = "payflow-alb"
ingress_namespace = "payflow"

tags = {
  Owner = "payflow-wallet"
}
