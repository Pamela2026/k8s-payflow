## Latest Amazon Linux 2023 AMI for bastion. ##
## Depends on: none. ##
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_caller_identity" "current" {}

## IAM role assumed by the bastion instance. ##
## Depends on: none. ##
resource "aws_iam_role" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name = "${var.name_prefix}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

## IAM policy for describing EKS clusters from the bastion. ##
## Depends on: aws_iam_role.bastion. ##
resource "aws_iam_role_policy" "bastion_eks_describe" {
  count = var.enable_bastion ? 1 : 0

  name = "${var.name_prefix}-bastion-eks-describe"
  role = aws_iam_role.bastion[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      Resource = "*"
    }]
  })
}

## IAM policy for bastion to run platform Terraform (state + EKS + IAM + EC2). ##
## Depends on: aws_iam_role.bastion. ##
resource "aws_iam_policy" "bastion_platform" {
  count = var.enable_bastion && var.tfstate_bucket_name != null && var.tfstate_lock_table_name != null ? 1 : 0

  name        = "${var.name_prefix}-bastion-platform"
  description = "Scoped permissions for bastion to run platform Terraform."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "TerraformStateS3",
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = "arn:aws:s3:::${var.tfstate_bucket_name}"
      },
      {
        Sid    = "TerraformStateObjects",
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = "arn:aws:s3:::${var.tfstate_bucket_name}/*"
      },
      {
        Sid    = "TerraformStateLock",
        Effect = "Allow",
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem"
        ],
        Resource = "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.tfstate_lock_table_name}"
      },
      {
        Sid    = "EKSControlPlane",
        Effect = "Allow",
        Action = [
          "eks:CreateCluster",
          "eks:DescribeCluster",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:DeleteCluster",
          "eks:ListClusters",
          "eks:CreateNodegroup",
          "eks:DescribeNodegroup",
          "eks:UpdateNodegroupConfig",
          "eks:UpdateNodegroupVersion",
          "eks:DeleteNodegroup",
          "eks:ListNodegroups",
          "eks:CreateAddon",
          "eks:DescribeAddon",
          "eks:UpdateAddon",
          "eks:DeleteAddon",
          "eks:DescribeAddonVersions",
          "eks:CreateAccessEntry",
          "eks:DeleteAccessEntry",
          "eks:DescribeAccessEntry",
          "eks:ListAccessEntries",
          "eks:AssociateAccessPolicy",
          "eks:DisassociateAccessPolicy",
          "eks:ListAssociatedAccessPolicies"
        ],
        Resource = "*"
      },
      {
        Sid    = "EC2ForEKS",
        Effect = "Allow",
        Action = [
          "ec2:Describe*",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:DeleteLaunchTemplate",
          "ec2:DeleteLaunchTemplateVersions",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ],
        Resource = "*"
      },
      {
        Sid    = "IAMScopedForEKS",
        Effect = "Allow",
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListRoleTags",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:PassRole"
        ],
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.name_prefix}-*"
        ]
      },
      {
        Sid    = "IAMOIDCScoped",
        Effect = "Allow",
        Action = [
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviders",
          "iam:TagOpenIDConnectProvider",
          "iam:UntagOpenIDConnectProvider"
        ],
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/*"
      },
      {
        Sid      = "IAMCreateServiceLinkedRoleForEKS",
        Effect   = "Allow",
        Action   = "iam:CreateServiceLinkedRole",
        Resource = "*",
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "eks.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_platform" {
  count      = var.enable_bastion && var.tfstate_bucket_name != null && var.tfstate_lock_table_name != null ? 1 : 0
  role       = aws_iam_role.bastion[0].name
  policy_arn = aws_iam_policy.bastion_platform[0].arn
}

## IAM policy for bastion to run workloads Terraform (RDS/ElastiCache/MQ/Secrets). ##
resource "aws_iam_policy" "bastion_workloads" {
  count = var.enable_bastion && var.enable_workloads_policy ? 1 : 0

  name        = "${var.name_prefix}-bastion-workloads"
  description = "Scoped permissions for bastion to run workloads Terraform."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "RDSWorkloads",
        Effect = "Allow",
        Action = [
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBSubnetGroups",
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:ModifyDBInstance",
          "rds:DescribeDBInstances",
          "rds:AddTagsToResource",
          "rds:ListTagsForResource"
        ],
        Resource = "*"
      },
      {
        Sid    = "ElastiCacheWorkloads",
        Effect = "Allow",
        Action = [
          "elasticache:CreateCacheSubnetGroup",
          "elasticache:DeleteCacheSubnetGroup",
          "elasticache:DescribeCacheSubnetGroups",
          "elasticache:CreateReplicationGroup",
          "elasticache:DeleteReplicationGroup",
          "elasticache:ModifyReplicationGroup",
          "elasticache:DescribeReplicationGroups",
          "elasticache:AddTagsToResource",
          "elasticache:ListTagsForResource",
          "elasticache:DescribeCacheClusters"
        ],
        Resource = "*"
      },
      {
        Sid    = "AmazonMQWorkloads",
        Effect = "Allow",
        Action = [
          "mq:CreateBroker",
          "mq:DeleteBroker",
          "mq:DescribeBroker",
          "mq:ListBrokers"
        ],
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerWorkloads",
        Effect = "Allow",
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource",
          "secretsmanager:GetResourcePolicy"
        ],
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}-*"
      },
      {
        Sid    = "WorkloadsSecurityGroups",
        Effect = "Allow",
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:Describe*",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_workloads" {
  count      = var.enable_bastion && var.enable_workloads_policy ? 1 : 0
  role       = aws_iam_role.bastion[0].name
  policy_arn = aws_iam_policy.bastion_workloads[0].arn
}

## Attach SSM core permissions for Session Manager. ##
## Depends on: aws_iam_role.bastion. ##
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  count      = var.enable_bastion ? 1 : 0
  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

## Instance profile for the bastion EC2 instance. ##
## Depends on: aws_iam_role.bastion. ##
resource "aws_iam_instance_profile" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name = "${var.name_prefix}-bastion-profile"
  role = aws_iam_role.bastion[0].name
}

## Security group for bastion access. ##
## Depends on: aws_vpc.* (via var.vpc_id). ##
resource "aws_security_group" "bastion" {
  count       = var.enable_bastion ? 1 : 0
  name        = "${var.name_prefix}-bastion-sg"
  description = "Bastion access (SSM-only unless SSH CIDRs are provided)"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ssh_cidr_blocks
    content {
      description = "Optional SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

## Bastion EC2 instance in hub public subnet. ##
## Depends on: aws_iam_instance_profile.bastion and aws_security_group.bastion. ##
resource "aws_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0

  ami                         = var.ami_id != null ? var.ami_id : data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion[0].id]
  iam_instance_profile        = aws_iam_instance_profile.bastion[0].name
  key_name                    = var.key_name

  user_data = <<-EOF
#!/bin/bash
set -euo pipefail
dnf install -y jq tar gzip unzip git nano awscli
dnf install -y amazon-ssm-agent
systemctl enable --now amazon-ssm-agent

# Install Terraform
TERRAFORM_VERSION="1.6.6"
curl -sSL "https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip" -o /tmp/terraform.zip
unzip -o /tmp/terraform.zip -d /usr/local/bin
rm -f /tmp/terraform.zip

# Install kubectl
KUBECTL_VERSION="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
curl -sSL "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

# Install Helm
curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Optional: auto-update kubeconfig on login if cluster name is provided.
if [[ -n "${var.eks_cluster_name}" ]]; then
  cat > /etc/profile.d/eks-kubeconfig.sh <<'PROFILE_EOF'
if command -v aws >/dev/null 2>&1; then
  aws eks update-kubeconfig --name "${var.eks_cluster_name}" --region "${var.region}" >/dev/null 2>&1 || true
fi
PROFILE_EOF
  chmod 644 /etc/profile.d/eks-kubeconfig.sh
fi
EOF

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion"
  })
}
