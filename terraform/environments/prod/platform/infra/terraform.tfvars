region               = "us-east-1"
environment          = "prod"
project_name         = "payflow"
cluster_name         = "payflow-eks-prod"
cluster_version      = "1.33"

node_instance_types  = ["t3.large"]
node_min_size        = 2
node_max_size        = 6
node_desired_size    = 2

endpoint_private_access = true
endpoint_public_access  = false

tags = {
  Owner = "payflow-wallet"
}
