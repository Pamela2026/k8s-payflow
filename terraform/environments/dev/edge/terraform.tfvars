region        = "us-east-1"
environment   = "dev"
project_name  = "payflow"

enable_cdn     = true
app_domain     = "computehub.online"
hosted_zone_id = "Z02373822JO7MP3G5ZLH"
alb_dns_name   = "afb486ec51bd74789a1d638010242db1-1269054456.us-east-1.elb.amazonaws.com"

tags = {
  Owner = "payflow-wallet"
}
