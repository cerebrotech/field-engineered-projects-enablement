# 🕊️   AWS Prerequisites 🕊️ 
Install boto3 library. You will need it to test IRSA. Some of the assumptions made in this enablement scenario-

1. EKS Account Id - `946429944765` Prod-Field deployment is in this AWS Account
2. AWS Assets Account Id - `524112250363` This is the account where your corporate assets like S3 buckets containing your corporate data are placed. 
   It would be ideal if you have some access to this account. But we can still run through most of this tutorial without it.
3. The OIDC Provider Attached to your EKS cluster is ` oidc.eks.us-west-2.amazonaws.com/id/6377798F9D92DFC7C9C3873B8DA27C68`
   If the prod-field deployments EKS cluster changes, so will this provider. And the IRSA service will need to be reinstalled.

## Assets AWS Account resources

In the Assests AWS Account you will find the following aws assets defined-

1. S3 bucket with name `arn:aws:s3:::domino-acme-test-bucket` - This is the test bucket we will attempt to list/read/update

2. IAM Policies - There are three relevant policies in this account: 
   a. `arn:aws:iam::524112250363:policy/acme-list-bucket-policy` 
   
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::domino-acme-test-bucket"
            ]
        }
    ]
}
```

   b.  `arn:aws:iam::524112250363:policy/acme-read-bucket-policy` 
   ```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ReadObjectsInBucket",
            "Effect": "Allow",
            "Action": [
                "s3:Get*"
            ],
            "Resource": [
                "arn:aws:s3:::domino-acme-test-bucket"
            ]
        }
    ]
}
```

   c.  `arn:aws:iam::524112250363:policy/acme-update-bucket-policy` 
   ```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "WriteObjectsInBucket",
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": [
                "arn:aws:s3:::domino-acme-test-bucket/*"
            ]
        },
        {
            "Sid": "DeleteObjectsInBucket",
            "Effect": "Allow",
            "Action": "s3:DeleteObject",
            "Resource": [
                "arn:aws:s3:::domino-acme-test-bucket/*"
            ]
        }
    ]
}
```

3. IAM Roles 
  a. `arn:aws:iam::524112250363:role/acme-list-bucket-role`. 
  b. `arn:aws:iam::524112250363:role/acme-read-bucket-role`
  c. `arn:aws:iam::524112250363:role/acme-update-bucket-role`
  
Roles with the same names will be defined in the EKS accounts and their intent is to be the src role for the corresponding role to assume in the assets account

## EKS AWS Account resources

In the EKS AWS Account you will find the following policies-

These policies will allow the roles attached to them to assume the corresponding role in the assets account

1. `arn:aws:iam::946429944765:policy/acme-list-bucket-policy`
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::524112250363:role/acme-list-bucket-role"
        }
    ]
}
```

2. `arn:aws:iam::946429944765:policy/acme-read-bucket-policy`
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::524112250363:role/acme-read-bucket-role"
        }
    ]
}
```

3. `arn:aws:iam::946429944765:policy/acme-update-bucket-policy`
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::524112250363:role/acme-update-bucket-role"
        }
    ]
}
```

And additional service policy is `arn:aws:iam::946429944765:policy/acme-irsa-svc-policy`. This policy allows the attached roles trust policy

```
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
            "Resource": "arn:aws:iam::946429944765:role/acme*"
        }
    ]
}
```

In the EKS Account the following roles are defined:
   

1. `arn:aws:iam::946429944765:role/acme-irsa-svc-role` - This is the role that the `irsa-svc` in the `domino-field` instance runs as.
    It is attached the policy `arn:aws:iam::946429944765:policy/acme-irsa-svc-policy` as the permission policy. It has the following trust policy
    
```
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::946429944765:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/6377798F9D92DFC7C9C3873B8DA27C68"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.us-west-2.amazonaws.com/id/6377798F9D92DFC7C9C3873B8DA27C68:aud": "sts.amazonaws.com",
                    "oidc.eks.us-west-2.amazonaws.com/id/6377798F9D92DFC7C9C3873B8DA27C68:sub": "system:serviceaccount:domino-field:irsa"
                }
            }
        }
    ]
   }
```
    This trust policy allows the irsa service running in the `domino-field` namespace with service account `irsa` assume this role.

2.  `arn:aws:iam::946429944765:role/acme-list-bucket-role`  with permission policy `arn:aws:iam::946429944765:policy/acme-list-bucket-policy`

3.  `arn:aws:iam::946429944765:role/acme-read-bucket-role`  with permission policy `arn:aws:iam::946429944765:policy/acme-read-bucket-policy`

4.  `arn:aws:iam::946429944765:role/acme-update-bucket-role`  with permission policy `arn:aws:iam::946429944765:policy/acme-update-bucket-policy`

The trust policy attached to the `acme-list-bucket-role`, `acme-read-bucket-role` and `acme-update-bucket-role` is
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::946429944765:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/6377798F9D92DFC7C9C3873B8DA27C68"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "oidc.eks.us-west-2.amazonaws.com/id/6377798F9D92DFC7C9C3873B8DA27C68:aud": "sts.amazonaws.com",
                    "oidc.eks.us-west-2.amazonaws.com/id/6377798F9D92DFC7C9C3873B8DA27C68:sub": ["*:domino-compute:run-646d27b817c28b5ea4b5b0c1"]
                }
            }
        }
    ]
}
```
Note the `sub` field, note the reference to the service account `domino-compute` namespace. This is what will allow the workload with that service account to assume this role using a `WEB IDENTITY TOKEN`