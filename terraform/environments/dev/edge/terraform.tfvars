region        = "us-east-1"
environment   = "dev"
project_name  = "payflow"

enable_cdn     = true
app_domain     = "computehub.online"
hosted_zone_id = "Z02373822JO7MP3G5ZLH"
alb_dns_name   = "k8s-payflow-payflowa-c8c7aef756-1703372593.us-east-1.elb.amazonaws.com"

tags = {
  Owner = "payflow-wallet"
}
