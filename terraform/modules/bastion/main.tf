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

## IAM role assumed by the bastion instance. ##
## Depends on: none. ##
resource "aws_iam_role" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name = "${var.name_prefix}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
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
