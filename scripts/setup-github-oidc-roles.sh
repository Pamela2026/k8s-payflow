#!/usr/bin/env bash
set -euo pipefail

# Create GitHub OIDC-backed IAM roles for Payflow CI/CD.
# Safe defaults:
# - build can push wallet images to ECR
# - plan roles are read-only plus backend access
# - apply roles are scoped per layer
# - verify roles can run bastion-based checks
# - sync-ingress has backend access only
#
# Optional env vars:
#   REPO_SLUG=Pamela2026/k8s-payflow
#   REGION=us-east-1
#   STATE_BUCKET=payflow-tfstate-003
#   LOCK_TABLE=payflow-tfstate-lock
#   KMS_KEY_ARN=
#   CREATE_OIDC_PROVIDER=false
#
# This script creates/updates:
#   payflow-build
#   payflow-<env>-foundation-plan|apply
#   payflow-<env>-platform-plan|apply|verify
#   payflow-<env>-addons-plan|apply|verify
#   payflow-<env>-edge-plan|apply|verify
#   payflow-<env>-sync-ingress

REPO_SLUG="${REPO_SLUG:-Pamela2026/k8s-payflow}"
REGION="${REGION:-us-east-1}"
STATE_BUCKET="${STATE_BUCKET:-payflow-tfstate-003}"
LOCK_TABLE="${LOCK_TABLE:-payflow-tfstate-lock}"
KMS_KEY_ARN="${KMS_KEY_ARN:-}"
CREATE_OIDC_PROVIDER="${CREATE_OIDC_PROVIDER:-false}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
OIDC_URL="https://token.actions.githubusercontent.com"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

WORK_DIR=".gh-iam"
mkdir -p "$WORK_DIR"

ensure_oidc_provider() {
  if [[ "$CREATE_OIDC_PROVIDER" != "true" ]]; then
    return 0
  fi

  if aws iam list-open-id-connect-providers \
    --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn | [0]" \
    --output text | grep -q 'token.actions.githubusercontent.com'; then
    echo "OIDC provider already exists."
    return 0
  fi

  echo "Creating GitHub OIDC provider..."
  aws iam create-open-id-connect-provider \
    --url "$OIDC_URL" \
    --client-id-list sts.amazonaws.com >/dev/null
}

create_trust_policy() {
  local subject="$1"
  local path="$2"

  cat > "$path" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_ARN"
      },
      "Action": [
        "sts:AssumeRoleWithWebIdentity",
        "sts:TagSession"
      ],
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "$subject"
        }
      }
    }
  ]
}
EOF
}

ensure_role_policy() {
  local role="$1"
  local name="$2"
  local path="$3"

  aws iam put-role-policy \
    --role-name "$role" \
    --policy-name "$name" \
    --policy-document "file://$path" >/dev/null
}

ensure_role() {
  local role_name="$1"
  local subject="$2"
  shift 2
  local policies=("$@")

  local trust_path="$WORK_DIR/${role_name}-trust.json"
  create_trust_policy "$subject" "$trust_path"

  if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    echo "Updating role: $role_name"
    aws iam update-assume-role-policy \
      --role-name "$role_name" \
      --policy-document "file://$trust_path" >/dev/null
  else
    echo "Creating role: $role_name"
    aws iam create-role \
      --role-name "$role_name" \
      --assume-role-policy-document "file://$trust_path" >/dev/null
  fi

  for entry in "${policies[@]}"; do
    IFS='|' read -r name path <<< "$entry"
    ensure_role_policy "$role_name" "$name" "$path"
  done
}

make_backend_policy() {
  local path="$1"

  cat > "$path" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::$STATE_BUCKET"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::$STATE_BUCKET/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:$REGION:$ACCOUNT_ID:table/$LOCK_TABLE"
    }
  ]
}
EOF

  if [[ -n "$KMS_KEY_ARN" ]]; then
    jq \
      --arg arn "$KMS_KEY_ARN" \
      '.Statement += [{
        "Effect":"Allow",
        "Action":["kms:Decrypt","kms:Encrypt","kms:GenerateDataKey","kms:DescribeKey"],
        "Resource":$arn
      }]' "$path" > "${path}.tmp" && mv "${path}.tmp" "$path"
  fi
}

make_readonly_policy() {
  local path="$1"
  cat > "$path" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:Get*",
        "ec2:Search*",
        "eks:Describe*",
        "eks:List*",
        "ecr:Describe*",
        "ecr:List*",
        "ecr:Get*",
        "acm:Describe*",
        "acm:List*",
        "route53:Get*",
        "route53:List*",
        "wafv2:Get*",
        "wafv2:List*",
        "cloudfront:Get*",
        "cloudfront:List*",
        "cloudfront:Describe*",
        "rds:Describe*",
        "rds:List*",
        "elasticache:Describe*",
        "elasticache:List*",
        "mq:Describe*",
        "mq:List*",
        "secretsmanager:Describe*",
        "secretsmanager:List*",
        "secretsmanager:Get*",
        "logs:Describe*",
        "logs:List*",
        "iam:Get*",
        "iam:List*",
        "ce:Get*",
        "ce:List*",
        "autoscaling:Describe*",
        "budgets:Describe*",
        "budgets:List*",
        "budgets:View*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

make_verify_policy() {
  local path="$1"
  local env_name="$2"
  cat > "$path" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster"
      ],
      "Resource": "arn:aws:eks:${REGION}:${ACCOUNT_ID}:cluster/payflow-eks-${env_name}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:SendCommand",
        "ssm:GetCommandInvocation",
        "ssm:ListCommandInvocations"
      ],
      "Resource": [
        "arn:aws:ec2:${REGION}:${ACCOUNT_ID}:instance/*",
        "arn:aws:ssm:${REGION}::document/AWS-RunShellScript"
      ],
      "Condition": {
        "StringLike": {
          "ssm:resourceTag/Name": [
            "*-${env_name}-bastion",
            "*-bastion"
          ]
        }
      }
    }
  ]
}
EOF
}

make_build_policy() {
  local path="$1"
  cat > "$path" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:DescribeRepositories",
        "ecr:BatchCheckLayerAvailability",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      "Resource": "arn:aws:ecr:${REGION}:${ACCOUNT_ID}:repository/payflow-wallet-*"
    }
  ]
}
EOF
}

make_foundation_apply_policy() {
  local path="$1"
  cat > "$path" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:ModifySubnetAttribute",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:CreateRoute",
        "ec2:ReplaceRoute",
        "ec2:DeleteRoute",
        "ec2:CreateInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        "ec2:AssociateAddress",
        "ec2:DisassociateAddress",
        "ec2:CreateNatGateway",
        "ec2:DeleteNatGateway",
        "ec2:DescribeNatGateways",
        "ec2:CreateVpcEndpoint",
        "ec2:DeleteVpcEndpoints",
        "ec2:DescribeVpcEndpoints",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:Describe*",
        "ec2:CreateTransitGateway",
        "ec2:DeleteTransitGateway",
        "ec2:CreateTransitGatewayRouteTable",
        "ec2:DeleteTransitGatewayRouteTable",
        "ec2:CreateTransitGatewayVpcAttachment",
        "ec2:DeleteTransitGatewayVpcAttachment",
        "ec2:DescribeTransitGateways",
        "ec2:DescribeTransitGatewayRouteTables",
        "ec2:DescribeTransitGatewayAttachments",
        "ec2:AssociateTransitGatewayRouteTable",
        "ec2:DisassociateTransitGatewayRouteTable",
        "ec2:EnableTransitGatewayRouteTablePropagation",
        "ec2:DisableTransitGatewayRouteTablePropagation",
        "ec2:CreateTransitGatewayRoute",
        "ec2:DeleteTransitGatewayRoute",
        "ec2:GetTransitGatewayRouteTableAssociations",
        "ec2:GetTransitGatewayRouteTablePropagations",
        "ec2:SearchTransitGatewayRoutes",
        "ecr:ListTagsForResource",
        "ecr:GetLifecyclePolicy",
        "budgets:ViewBudget",
        "budgets:ListTagsForResource",
        "ce:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:CreateRepository",
        "ecr:DeleteRepository",
        "ecr:PutLifecyclePolicy",
        "ecr:GetLifecyclePolicy",
        "ecr:DeleteLifecyclePolicy",
        "ecr:SetRepositoryPolicy",
        "ecr:TagResource",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:ListTagsForResource"
      ],
      "Resource": "arn:aws:ecr:${REGION}:${ACCOUNT_ID}:repository/payflow-wallet-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:PassRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:CreatePolicyVersion",
        "iam:DeletePolicyVersion",
        "iam:TagRole",
        "iam:GetRole",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:GetInstanceProfile",
        "iam:GetOpenIDConnectProvider",
        "iam:ListRoles",
        "iam:ListPolicies",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:ListPolicyVersions",
        "iam:ListRoleTags",
        "iam:ListOpenIDConnectProviders",
        "iam:ListInstanceProfilesForRole"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "budgets:CreateBudget",
        "budgets:ModifyBudget",
        "budgets:DeleteBudget",
        "budgets:TagResource",
        "budgets:UntagResource",
        "budgets:ListTagsForResource",
        "ce:CreateAnomalyMonitor",
        "ce:DeleteAnomalyMonitor",
        "ce:GetAnomalyMonitors",
        "ce:GetAnomalySubscriptions",
        "ce:ListTagsForResource",
        "budgets:ViewBudget",
        "ce:ListAnomalyMonitors",
        "ce:ListAnomalySubscriptions",
        "ce:CreateAnomalySubscription",
        "ce:DeleteAnomalySubscription",
        "sns:CreateTopic",
        "sns:DeleteTopic",
        "sns:Subscribe",
        "sns:SetTopicAttributes"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecret",
        "secretsmanager:TagResource",
        "secretsmanager:UntagResource",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecrets",
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:StopInstances",
        "ec2:StartInstances",
        "ec2:RebootInstances",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifyInstancePlacement"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

make_platform_apply_policy() {
  local path="$1"
  cat > "$path" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:CreateCluster",
        "eks:DeleteCluster",
        "eks:UpdateClusterConfig",
        "eks:UpdateClusterVersion",
        "eks:CreateNodegroup",
        "eks:DeleteNodegroup",
        "eks:UpdateNodegroupConfig",
        "eks:UpdateNodegroupVersion",
        "eks:CreateAccessEntry",
        "eks:DeleteAccessEntry",
        "eks:AssociateAccessPolicy",
        "eks:DisassociateAccessPolicy",
        "eks:CreateAddon",
        "eks:DeleteAddon",
        "eks:UpdateAddon",
        "eks:TagResource",
        "eks:UntagResource",
        "eks:Describe*",
        "eks:List*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:RunInstances",
        "ec2:CreateLaunchTemplate",
        "ec2:DeleteLaunchTemplate",
        "ec2:CreateLaunchTemplateVersion",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:Describe*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:PassRole",
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:TagOpenIDConnectProvider",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:CreatePolicyVersion",
        "iam:DeletePolicyVersion",
        "iam:TagRole",
        "iam:CreateServiceLinkedRole",
        "iam:GetRole",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:GetInstanceProfile",
        "iam:GetOpenIDConnectProvider",
        "iam:ListRoles",
        "iam:ListPolicies",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:ListPolicyVersions",
        "iam:ListRoleTags",
        "iam:ListOpenIDConnectProviders",
        "iam:ListInstanceProfilesForRole"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:Describe*",
        "autoscaling:CreateAutoScalingGroup",
        "autoscaling:DeleteAutoScalingGroup",
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:CreateLaunchConfiguration",
        "autoscaling:DeleteLaunchConfiguration"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:CreateRepository",
        "ecr:DeleteRepository",
        "ecr:PutLifecyclePolicy",
        "ecr:SetRepositoryPolicy",
        "ecr:TagResource",
        "ecr:ListTagsForResource",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages"
      ],
      "Resource": "arn:aws:ecr:${REGION}:${ACCOUNT_ID}:repository/payflow-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "rds:CreateDBInstance",
        "rds:DeleteDBInstance",
        "rds:ModifyDBInstance",
        "rds:CreateDBSubnetGroup",
        "rds:DeleteDBSubnetGroup",
        "rds:CreateDBParameterGroup",
        "rds:DeleteDBParameterGroup",
        "rds:ModifyDBParameterGroup",
        "rds:DescribeDBParameterGroups",
        "rds:AddTagsToResource",
        "rds:ListTagsForResource",
        "rds:Describe*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticache:CreateReplicationGroup",
        "elasticache:DeleteReplicationGroup",
        "elasticache:CreateCacheSubnetGroup",
        "elasticache:DeleteCacheSubnetGroup",
        "elasticache:AddTagsToResource",
        "elasticache:ListTagsForResource",
        "elasticache:Describe*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "mq:CreateBroker",
        "mq:DeleteBroker",
        "mq:UpdateBroker",
        "mq:CreateTags",
        "mq:DeleteTags",
        "mq:ListTagsForResource",
        "mq:Describe*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecret",
        "secretsmanager:TagResource",
        "secretsmanager:ListTagsForResource",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecrets",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "acm:RequestCertificate",
        "acm:DeleteCertificate",
        "acm:AddTagsToCertificate",
        "acm:DescribeCertificate",
        "acm:ListCertificates"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ChangeTagsForResource",
        "route53:GetHostedZone",
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:GetChange"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

make_addons_apply_policy() {
  local path="$1"
  local env_name="$2"
  cat > "$path" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:TagResource",
        "eks:UntagResource"
      ],
      "Resource": "arn:aws:eks:${REGION}:${ACCOUNT_ID}:cluster/payflow-eks-${env_name}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:SendCommand",
        "ssm:GetCommandInvocation",
        "ssm:ListCommandInvocations"
      ],
      "Resource": [
        "arn:aws:ec2:${REGION}:${ACCOUNT_ID}:instance/*",
        "arn:aws:ssm:${REGION}::document/AWS-RunShellScript"
      ],
      "Condition": {
        "StringLike": {
          "ssm:resourceTag/Name": [
            "*-bastion"
          ]
        }
      }
    }
  ]
}
EOF
}

make_edge_apply_policy() {
  local path="$1"
  cat > "$path" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateDistribution",
        "cloudfront:UpdateDistribution",
        "cloudfront:DeleteDistribution",
        "cloudfront:CreateOriginAccessControl",
        "cloudfront:DeleteOriginAccessControl",
        "cloudfront:TagResource",
        "cloudfront:Describe*",
        "cloudfront:Get*",
        "cloudfront:List*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "wafv2:CreateWebACL",
        "wafv2:UpdateWebACL",
        "wafv2:DeleteWebACL",
        "wafv2:CreateRuleGroup",
        "wafv2:DeleteRuleGroup",
        "wafv2:TagResource",
        "wafv2:GetWebACL",
        "wafv2:ListWebACLs",
        "wafv2:GetWebACLForResource",
        "wafv2:AssociateWebACL",
        "wafv2:DisassociateWebACL"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ChangeTagsForResource",
        "route53:GetHostedZone",
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:GetChange"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "acm:RequestCertificate",
        "acm:DeleteCertificate",
        "acm:AddTagsToCertificate",
        "acm:DescribeCertificate",
        "acm:ListCertificates"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

make_sync_ingress_policy() {
  local path="$1"
  cat > "$path" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::$STATE_BUCKET"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::$STATE_BUCKET/*"
    }
  ]
}
EOF
}

print_role_arn() {
  local role="$1"
  aws iam get-role --role-name "$role" --query 'Role.Arn' --output text
}

main() {
  ensure_oidc_provider

  make_backend_policy "$WORK_DIR/backend.json"
  make_readonly_policy "$WORK_DIR/readonly.json"

  make_build_policy "$WORK_DIR/build.json"
  make_foundation_apply_policy "$WORK_DIR/foundation-apply.json"
  make_platform_apply_policy "$WORK_DIR/platform-apply.json"
  make_edge_apply_policy "$WORK_DIR/edge-apply.json"
  make_sync_ingress_policy "$WORK_DIR/sync-ingress.json"

  ENVS=(dev staging prod)

  ensure_role \
    "payflow-build" \
    "repo:${REPO_SLUG}:environment:build" \
    "backend|$WORK_DIR/backend.json" \
    "build|$WORK_DIR/build.json"

  for env in "${ENVS[@]}"; do
    make_verify_policy "$WORK_DIR/${env}-verify.json" "$env"
    make_addons_apply_policy "$WORK_DIR/${env}-addons-apply.json" "$env"

    ensure_role \
      "payflow-${env}-foundation-plan" \
      "repo:${REPO_SLUG}:environment:${env}-foundation-plan" \
      "backend|$WORK_DIR/backend.json" \
      "readonly|$WORK_DIR/readonly.json"

    ensure_role \
      "payflow-${env}-foundation-apply" \
      "repo:${REPO_SLUG}:environment:${env}-foundation-apply" \
      "backend|$WORK_DIR/backend.json" \
      "foundation-apply|$WORK_DIR/foundation-apply.json"

    ensure_role \
      "payflow-${env}-platform-plan" \
      "repo:${REPO_SLUG}:environment:${env}-platform-plan" \
      "backend|$WORK_DIR/backend.json" \
      "readonly|$WORK_DIR/readonly.json"

    ensure_role \
      "payflow-${env}-platform-apply" \
      "repo:${REPO_SLUG}:environment:${env}-platform-apply" \
      "backend|$WORK_DIR/backend.json" \
      "platform-apply|$WORK_DIR/platform-apply.json"

    ensure_role \
      "payflow-${env}-platform-verify" \
      "repo:${REPO_SLUG}:environment:${env}-platform-verify" \
      "readonly|$WORK_DIR/readonly.json" \
      "verify|$WORK_DIR/${env}-verify.json"

    ensure_role \
      "payflow-${env}-addons-plan" \
      "repo:${REPO_SLUG}:environment:${env}-addons-plan" \
      "backend|$WORK_DIR/backend.json" \
      "readonly|$WORK_DIR/readonly.json"

    ensure_role \
      "payflow-${env}-addons-apply" \
      "repo:${REPO_SLUG}:environment:${env}-addons-apply" \
      "backend|$WORK_DIR/backend.json" \
      "addons-apply|$WORK_DIR/${env}-addons-apply.json"

    ensure_role \
      "payflow-${env}-addons-verify" \
      "repo:${REPO_SLUG}:environment:${env}-addons-verify" \
      "readonly|$WORK_DIR/readonly.json" \
      "verify|$WORK_DIR/${env}-verify.json"

    ensure_role \
      "payflow-${env}-edge-plan" \
      "repo:${REPO_SLUG}:environment:${env}-edge-plan" \
      "backend|$WORK_DIR/backend.json" \
      "readonly|$WORK_DIR/readonly.json"

    ensure_role \
      "payflow-${env}-edge-apply" \
      "repo:${REPO_SLUG}:environment:${env}-edge-apply" \
      "backend|$WORK_DIR/backend.json" \
      "edge-apply|$WORK_DIR/edge-apply.json"

    ensure_role \
      "payflow-${env}-edge-verify" \
      "repo:${REPO_SLUG}:environment:${env}-edge-verify" \
      "readonly|$WORK_DIR/readonly.json" \
      "verify|$WORK_DIR/${env}-verify.json"

    ensure_role \
      "payflow-${env}-sync-ingress" \
      "repo:${REPO_SLUG}:environment:${env}-sync-ingress" \
      "backend|$WORK_DIR/backend.json" \
      "sync-ingress|$WORK_DIR/sync-ingress.json"
  done

  echo
  echo "Roles created/updated:"
  for role in \
    payflow-build \
    payflow-dev-foundation-plan payflow-dev-foundation-apply \
    payflow-dev-platform-plan payflow-dev-platform-apply payflow-dev-platform-verify \
    payflow-dev-addons-plan payflow-dev-addons-apply payflow-dev-addons-verify \
    payflow-dev-edge-plan payflow-dev-edge-apply payflow-dev-edge-verify \
    payflow-dev-sync-ingress \
    payflow-staging-foundation-plan payflow-staging-foundation-apply \
    payflow-staging-platform-plan payflow-staging-platform-apply payflow-staging-platform-verify \
    payflow-staging-addons-plan payflow-staging-addons-apply payflow-staging-addons-verify \
    payflow-staging-edge-plan payflow-staging-edge-apply payflow-staging-edge-verify \
    payflow-staging-sync-ingress \
    payflow-prod-foundation-plan payflow-prod-foundation-apply \
    payflow-prod-platform-plan payflow-prod-platform-apply payflow-prod-platform-verify \
    payflow-prod-addons-plan payflow-prod-addons-apply payflow-prod-addons-verify \
    payflow-prod-edge-plan payflow-prod-edge-apply payflow-prod-edge-verify \
    payflow-prod-sync-ingress
  do
    if aws iam get-role --role-name "$role" >/dev/null 2>&1; then
      print_role_arn "$role"
    fi
  done
}

main "$@"
