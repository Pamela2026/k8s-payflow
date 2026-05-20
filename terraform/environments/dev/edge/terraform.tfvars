region        = "us-east-1"
environment   = "dev"
project_name  = "payflow"

# Edge is disabled in the current setup.
# Activate the configuration if you own a domain and want to set up a CDN and WAF for your application.
# enable_cdn     = true
# app_domain     = "computehub.online"
# hosted_zone_id = "Z02373822JO7MP3G5ZLH"
# alb_dns_name   = "k8s-payflow-payflowa-c8c7aef756-1703372593.us-east-1.elb.amazonaws.com"
#
# enable_waf                     = true
# waf_rate_limit                 = 2000
# waf_enable_common_rule_set     = true
# waf_enable_bad_inputs_rule_set = true
# waf_enable_sqli_rule_set       = true
# waf_enable_rate_limit          = true

tags = {
  Owner = "payflow-wallet"
}
