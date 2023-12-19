# Example implementation of AWS resources required for Domino IRSA

This directory contains an example of the roles and policies involved in [allowing Domino workloads to assume AWS IAM roles](https://github.com/dominodatalab/irsa_installation)
across (or within) AWS accounts.

## Pre-requisites

Create an IAM OIDC provider for your cluster using [eksctl or AWS Management Console](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html)

## Requirements

This code assumes that you have access to two separate AWS accounts, and that you have an awscli configuration with two profiles:

1. Account: `domino-eks`. This account contains the EKS cluster that runs your Domino workloads. This account will be used to set up the [IRSA service account for the Domino IRSA app](domino_irsa_svc.tf), as well an [example proxy role](proxy_irsa.tf) that the app will modify dynamically to allow users to assume this proxy role.

2. Account: `asset-acct`. This account contains whatever AWS resources you want your Domino users to be able to access. For the purpose of this example,
we've set up [an example IAM policy that can list the S3 buckets within this account](demo_workload_policy.tf).

NOTE: this _can_ run within one AWS account, but two awscli profiles would still be required.

If you wish to define a policy for a various workload role, you can pass the policy definition as a value for the variable `irsa-workload-policy` in the workload role module call. It is recommended to use a [Terraform IAM policy document object](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) for this ([example here](demo_workload_policy.tf)), but any valid IAM policy JSON can be passed in. If you do not pass in any policy definition to a given workload role, you will have to create and attach the policy to the workload role after it is created.

## Setup

Create a `demo.tfvars` file with the name of your cluster in it:

```shell
eks-cluster-name = "<YOUR_CLUSTER_NAME>"
```

Run `terraform init` to initialize the AWS provider.

Run `terraform plan -var-file=demo.tfvars` to show the changes that will be made. With the un-modified code from this repo, you should see 19 resources to be added.

## Deploy

Run `terraform apply -var-file=demo.tfvars` to apply the planned changes. Type "yes" when prompted.

## Destroy (optional)

Run `terraform destroy -var-file=demo.tfvars` to remove all of the applied changes. Type "yes" when prompted.

## Validation

At the end of the `Deploy` step, if everything applied successfully, you should have the following in your accounts (below assumes a cluster named `demo`):

### Account: **domino-eks**

IAM Role: `demo-domino-irsa-svc-role`

This role has the following policy associated:
```json
{
    "Statement": [
        {
            "Action": [
                "iam:UpdateAssumeRolePolicy",
                "iam:PutRolePolicy",
                "iam:ListRoles",
                "iam:ListRolePolicies",
                "iam:ListPolicyVersions",
                "iam:ListPolicies",
                "iam:GetRole"
            ],
            "Effect": "Allow",
            "Resource": [
                "<PROXY_ROLE_ARNS>"
            ],
            "Sid": "IRSAAdmin"
        }
    ],
    "Version": "2012-10-17"
}
```

The `assume_role_policy` for this role ties to the IRSA service account within the cluster in question:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "<EKS_CLUSTER_OIDC_PROVIDER_ARN>"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "<EKS_CLUSTER_OIDC_PROVIDER_HOSTNAME>:sub": "system:serviceaccount:domino-field:irsa"
                }
            }
        }
    ]
}
```

You should have 3x proxy roles as well: `demo-domino-proxy-list-bucket-role-1`, `demo-domino-proxy-read-bucket-role-1`, `demo-domino-proxy-write-bucket-role-1`. Each of these roles will have a policy similar to this:

```json
{
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Effect": "Allow",
            "Resource": <ASSOCIATED_WORKLOAD_ROLE_ARN>
        }
    ],
    "Version": "2012-10-17"
}
```

where <ASSOCIATED_WORKLOAD_ROLE_ARN> is the ARN of the workload role associated to the proxy role. **NOTE** proxy roles have a many:1 association with workload roles. Each workload role may be associated with several proxy roles, but each proxy role will only be associated with a single workload role.

Each proxy role will also have an `assume_role_policy` similar to this:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "<EKS_CLUSTER_OIDC_PROVIDER_ARN>"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "<EKS_CLUSTER_OIDC_PROVIDER_HOSTNAME>:sub": ""
                }
            }
        }
    ]
}
```

Note that the `sub` value here is empty: this will be modified as needed by the IRSA service to add/remove the service account(s) for a given run, based on the contents of the `ConfigMap` "domino-org-iamrole-mapping".

### Account: **asset-acct**

This account is where all of the workload IAM roles will be found. With this codebase, there are three: `demo-domino-list-bucket-role`, `demo-domino-read-bucket-role`, `demo-domino-write-bucket-role`. Since this is a demo codebase, we only have one policy for all three workloads (despite the naming differences to the contrary). All of the workload roles in this case use the list-bucket policy defined in [demo_workload_policy.tf](demo_workload_policy.tf):

```json
{
    "Statement": [
        {
            "Action": "s3:ListBucket",
            "Effect": "Allow",
            "Resource": "*"
        }
    ],
    "Version": "2012-10-17"
}
```

Each workload policy also has an `assume_role_policy` similar to this:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": ["<ASSOCIATED_PROXY_ROLE_ARNS>"]
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

where <ASSOCIATED_PROXY_ROLE_ARN> is the ARN of the proxy role associated to the workload role. **REMINDER:** proxy roles have a many:1 association with workload roles. Each workload role may be associated with several proxy roles, but each proxy role will only be associated with a single workload role.

## Maintenance Note

When adding any new proxy roles, make sure that you modify the policy for the service role so that the latter can modify the trust policies for the former. You can find this in the object `data.aws_iam_policy_document.domino-irsa-svc-policy` in [domino_irsa_svc.tf](domino_irsa_svc.tf). In the `resources` section of the data object, add the following to the `concat` function:

`module.<proxy_role_module_name>[*].proxy-role-arn`

This will allow the IRSA service role to dynamically modify all of the proxy roles created by the new proxy role module call.