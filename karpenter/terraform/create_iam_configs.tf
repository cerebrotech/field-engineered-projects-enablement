# Define Variables - values will be read form the terraform.tfvars


variable "CLUSTER_NAME" {
  description = "The name of the EKS cluster"
  type        = string
  default     = ""
}

# Retrieve EKS values
data "external" "cluster_endpoint" {
  program = ["sh", "-c", "aws eks describe-cluster --name ${var.CLUSTER_NAME} | jq  '{endpoint: .cluster.endpoint}' "]
}

data "external" "oidc_endpoint" {
  program = ["sh", "-c", "aws eks describe-cluster --name ${var.CLUSTER_NAME}  | jq  '{issuer: .cluster.identity.oidc.issuer}' "]
}

data "aws_caller_identity" "current" {}

locals {
  CLUSTER_ENDPOINT = data.external.cluster_endpoint.result["endpoint"]
  OIDC_ENDPOINT    = data.external.oidc_endpoint.result["issuer"]
  OIDC_ENDPOINT_TRIM    = trim(data.external.oidc_endpoint.result["issuer"], "https://")
  AWS_ACCOUNT_ID   = data.aws_caller_identity.current.account_id
}

#print local vars
output "cluster_endpoint" {
  value = local.CLUSTER_ENDPOINT
}

output "oidc_endpoint" {
  value = local.OIDC_ENDPOINT
}

output "oidc_endpoint_trimmed" {
  value = local.OIDC_ENDPOINT_TRIM
}

output "aws_acct_id" {
  value = local.AWS_ACCOUNT_ID
}

#Create new IAM provider for the EKS OIDC endpoint
module "account_iam-oidc-identity-provider" {
  source  = "tedilabs/account/aws//modules/iam-oidc-identity-provider"
  version = "0.24.0"
  url = local.OIDC_ENDPOINT
  audiences = ["sts.amazonaws.com"]
}

# Create a new IAM role for Karpenter Nodes
resource "aws_iam_role" "KarpenterInstanceNodeRole" {
  name = "KarpenterInstanceNodeRole-${var.CLUSTER_NAME}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach IAM policies to Karpenter node role
resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.KarpenterInstanceNodeRole.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.KarpenterInstanceNodeRole.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.KarpenterInstanceNodeRole.name
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.KarpenterInstanceNodeRole.name
}

# Craeate IAM EC2 instance profile and atatch the Instance Node role
resource "aws_iam_instance_profile" "KarpenterInstanceProfile" {
  name = "KarpenterInstanceProfile-${var.CLUSTER_NAME}"
 
  role = aws_iam_role.KarpenterInstanceNodeRole.name
}
# Create IAM role for Karpenter controlelrs


resource "aws_iam_role" "karpenter_controller_role" {
  name               = "KarpenterControllerRole-${var.CLUSTER_NAME}"
  assume_role_policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Principal: {
          Federated: "arn:aws:iam::${local.AWS_ACCOUNT_ID}:oidc-provider/${local.OIDC_ENDPOINT_TRIM}"
        },
        Action: "sts:AssumeRoleWithWebIdentity",
        Condition: {
          StringEquals: {
            "${local.OIDC_ENDPOINT}:aud": "sts.amazonaws.com",
            "${local.OIDC_ENDPOINT}:sub": "system:serviceaccount:karpenter:karpenter"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "karpenter_controller_policy" {
  name  = "KarpenterControllerPolicy-${var.CLUSTER_NAME}"
  role  = aws_iam_role.karpenter_controller_role.name
  policy = jsonencode({
    Statement: [
      {
        Action: [
          "ssm:GetParameter",
          "iam:PassRole",
          "ec2:DescribeImages",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts"
        ],
        Effect:   "Allow",
        Resource: "*",
        Sid:      "Karpenter"
      },
      {
        Action: "ec2:TerminateInstances",
        Condition: {
          StringLike: {
            "ec2:ResourceTag/Name": "*karpenter*"
          }
        },
        Effect:   "Allow",
        Resource: "*",
        Sid:      "ConditionalEC2Termination"
      }
    ],
    Version: "2012-10-17"
  })
}
