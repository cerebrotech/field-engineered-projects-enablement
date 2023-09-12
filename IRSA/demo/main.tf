# Define the AWS provider
provider "aws" {
  region = "us-west-2"  # Replace with your desired region
}
locals {
  prefix = "test-acme"
  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]
  eks-account-no = "946429944765"
  irsa-svc-role-name = "${local.prefix}-irsa-svc-role"
  irsa-svc-policy-name = "${local.prefix}-irsa-svc-policy"
  eks-region = "us-west-2"
  oidc-provider-id = "6377798F9D92DFC7C9C3873B8DA27C68"
  irsa-service-account = "system:serviceaccount:domino-field:irsa"
}

# Use the iam_assumable_role_oidc module
module "irsa-svc-role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  create_role = true
  aws_account_id = local.eks-account-no
  role_name              = local.irsa-svc-role-name
  provider_url           = "oidc.eks.${local.eks-region}.amazonaws.com/id/${local.oidc-provider-id}"
  provider_urls          = ["oidc.eks.${local.eks-region}.amazonaws.com/id/${local.oidc-provider-id}"]
  oidc_fully_qualified_subjects = ["${local.irsa-service-account}"]
  oidc_fully_qualified_audiences = local.oidc_fully_qualified_audiences
}

# Create an IAM policy
resource "aws_iam_policy" "irsa-svc-policy" {
  name        = local.irsa-svc-policy-name
  description = "Policy for IRSA Service Account"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "acmeirsaadmin1",
            "Effect": "Allow",
            "Action": [
                "iam:ListPolicies",
                "iam:ListPolicyVersions",
                "iam:ListRolePolicies",
                "iam:ListRoles",
                "iam:GetRole",
                "iam:PutRolePolicy",
                "iam:UpdateAssumeRolePolicy"
            ],
            "Resource": "arn:aws:iam::${local.eks-account-no}:role/${local.prefix}*"
        }
    ]
}
EOF
}

# Attach the policy to the IAM role
resource "aws_iam_role_policy_attachment" "policy_attachment" {
  role       = module.irsa-svc-role.iam_role_name
  policy_arn = aws_iam_policy.irsa-svc-policy.arn
}

# Output the IAM role ARN
output "role_arn" {
  value = module.irsa-svc-role.iam_role_arn
}