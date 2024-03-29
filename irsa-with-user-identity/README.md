# IRSA With User Identity

This mechanism for using IRSA is a considerably simplified version compared to the alternative in this repo.

Domino creates a new K8s Service Account for each workload with the same name as the `run-id`. IRSA which
stands for "IAM ROLE to Service Account" relies on mapping the K8s Service Account to an IAM Role.

This mapping is done via the IAM Role Trust Policy. Essentially it is a Web Identity Based Authentication the
details of which are outlined in the following blog articles-
- [IAM Roles of K8s Service Accounts Deep Dive](https://mjarosie.github.io/dev/2021/09/15/iam-roles-for-kubernetes-service-accounts-deep-dive.html)
- [EKS Pod Identity Webhook Deep Dive](https://blog.mikesir87.io/2020/09/eks-pod-identity-webhook-deep-dive/)


Given the dynamic nature of these Service Accounts, the mappings can only be created when the workload is  being started.
However, user to role mappings are by nature static in nature and rarely change. Customers wanted to 
manage this mapping outside of Domino. To achieve this goal we have come up with the following simplified design.

We create a K8s  Service Account per Domino User. When the workload is coming up, we replace the 
workload SA with the user SA and update the `RoleBindings` for the workload to use the user SA principal.

This allows us to bypass configuring the trust relationship for this SA completely as this is meant to be
managed statically by the DevOps team. 




## Pre-requisites

> Check with your Domino CSM before using this capability. It is a significant departure from how Domino manages
> pod identities and may not be suitable for your requirements. It is currently only tested upto Domino version 5.8

1. Install v1.3.2-release and above
2. For users needing to assume AWS role identities create service account per user in the `domino-compute` namespace. 
   The name of the service account should match the user-name

When we switch to domino_user_name based service account as opposed to run_id based service accounts, there are restrictions on how we define our domino user name. It must now conform to the constraint-

> A lowercase RFC 1123 subdomain must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'Example Domain ', regex used for validation is 'a-z0-9?(\.a-z0-9?)*')

For example a user name test_user is allowed by Keycloak/Domino. However a K8s service account cannot be named test_user . It can only be named test-user or test.user

For new customers this is not a problem. Retrofitting it for existing customers may need require us to map invalid characters (invalid for K8s SA) with a - or a .

For this enablement assume that the `DominoUserName==K8sServiceAccountName`

## Installation

1. Update the [mutation](user-identity-based-irsa.yaml) as follows:

Update the environment variable mutation as appropriate to your environment

```yaml
  modifyEnv:
    env:
    - name: AWS_WEB_IDENTITY_TOKEN_FILE
      value: /var/run/secrets/eks.amazonaws.com/serviceaccount/token
    - name: AWS_CONFIG_FILE
      value: /var/run/.aws/config
    - name: AWS_DEFAULT_REGION
      value: us-west-2
    - name: AWS_REGION
      value: us-west-2
    - name: AWS_STS_REGIONAL_ENDPOINTS
      value: regional
```
Next update the user to K8s service account mappings (see Pre-requisites)

```yaml
- cloudWorkloadIdentity:
    cloud_type: aws
    default_sa: ""
    assume_sa_mapping: true
```
Alternatively you can provide explicitly mappings between users and K8s Service Accounts. Use this mechanism
when you cannot assume identical names

```yaml
- cloudWorkloadIdentity:
    cloud_type: aws
    default_sa: ""    
    user_mappings:
      domino-sameerw: sameerw
      domino-vaibhavd: vaibhavd
      domino-marcd: marcd
```


2. Apply the mutations

```shell
export platform_namespace=domino-platform
kubectl -n ${platform_namespace} apply -f ./user-identity-based-irsa.yaml
```

3. Update your AWS trust policy for the role the user wants to assume (Ex. AWS Role `sw-irsa-test-role`)

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::111111111111:oidc-provider/oidc.eks.<AWS_REGION>.amazonaws.com/id/<OIDC_ID>"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "oidc.eks.<AWS_REGION>.amazonaws.com/id/<OIDC_ID>:sub": [
                       "system:serviceaccount:domino-compute:vaibhavd",
                        "system:serviceaccount:domino-compute:sameerw",
                        "system:serviceaccount:domino-compute:marcd"
                    ]
                }
            }
        }
    ]
}
```

4. Next as one of the mapped users start a workspace and run the following Python code

```python
import os
## You can change this to any role you (based on the k8s service account) have permission to assume
os.environ['AWS_ROLE_ARN']='arn:aws:iam::111111111111:role/sw-irsa-test-role'

## Now verify you have assumed it successfully
import boto3.session
session = boto3.session.Session()
sts_client = session.client('sts')
sts_client.get_caller_identity()
```

This should produce the output below which indicates that you have successfully assumed the role

```shell
{'UserId': 'AROA5YW464O6XT4444V43:botocore-session-1701963056',
 'Account': '111111111111',
 'Arn': 'arn:aws:sts::111111111111:assumed-role/sw-irsa-test-role/botocore-session-1701963056',
 'ResponseMetadata': {'RequestId': '77f078d6-237f-4351-9527-c959d7b409a8',
  'HTTPStatusCode': 200,
  'HTTPHeaders': {'x-amzn-requestid': '77f078d6-237f-4351-9527-c959d7b409a8',
   'content-type': 'text/xml',
   'content-length': '478',
   'date': 'Thu, 07 Dec 2023 15:30:56 GMT'},
  'RetryAttempts': 0}}

```


## Future RSA/RSE Work

Additional work may be needed to meet unique customer requirements. This will be done as RSA/RSE offering

1. Generate a `AWS_CONFIG_FILE` based on pre-defined mapping (Ex. IAMRoles->Orgs->Users)
2. Generate a `AWS_CONFIG_FILE` based on attributes arriving in the user JWT
3. Generate a `AWS_CONFIG_FILE` to support cross account access 
   
In all of the situations above we should encourage the customers to bring their own CONFIG file instead. 
The reason for that being, a user/workload is supposed to know what role it is assuming. Beause trust
relationships are configured behind the scenes, a user cannot assume a role  they are not allowed to

## Appendix - Inner workings of AWS IRSA Webhook


## A brief tour of how AWS handles the Service Account annotations for roles for IRSA

To understand how AWS handles IRSA using annotations create a K8s service account in the `domino-compute` namespace 
exactly as below
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: integration-test
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::111122223333:role/my-role
```
Note that the annotation value for `eks.amazonaws.com/role-arn` above is a non-existent account, as well as IAM role

Now create a pod as follows using the above service account:
```shell
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: run-xyz-1
  namespace: domino-compute  
spec:
  serviceAccountName: integration-test
  containers:
  - name: main
    image: demisto/boto3py3:1.0.0.81279
    command: ["sleep", "infinity"]
EOF
```

Now let us shell into this pod

```shell
kubectl -n domino-compute exec -it run-xyz-1 -- sh
```

Now run the following commands inside the pod shell

```shell
 # env | grep AWS
AWS_ROLE_ARN=arn:aws:iam::111122223333:role/my-role
AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
AWS_STS_REGIONAL_ENDPOINTS=regional
AWS_DEFAULT_REGION=us-west-2
AWS_REGION=us-west-2
```

Note the above output. How did those environment variables appear. Also how did the mount appear. If you `cat` the file 
`/var/run/secrets/eks.amazonaws.com/serviceaccount/token` you will notice that it refers to a projected service account
token. Who injected these environment variables and the mount

This was injected by an AWS webhook called the `pod-identity-webhook`

```shell
kubectl -n kube-system get mutatingwebhookconfigurations

pod-identity-webhook                          1          30d
vpc-resource-mutating-webhook                 1          30d

```

This webhook is watching pods as they come up. And if the service account attached to this pod has the annotation  
`eks.amazonaws.com/role-arn` attached to it, it applies mutations which adds the projected service token mount and
the corresponding environment variables. Note that the actual role arn mentioned in the annotations does not even need
to exist. Next inside the shell open a `python3` shell and run the following

```shell
# python3
Python 3.10.13 (main, Oct 19 2023, 06:08:04) [GCC 12.2.1 20220924] on linux
Type "help", "copyright", "credits" or "license" for more information.
---
import os
import boto3
import boto3.session
session = boto3.session.Session()
sts_client = session.client('sts')
sts_client.get_caller_identity()

...
botocore.errorfactory.InvalidIdentityTokenException: An error occurred (InvalidIdentityToken) when calling the AssumeRoleWithWebIdentity operation: No OpenIDConnect provider found in your account for https://oidc.eks.us-west-2.amazonaws.com/id/C7F107CAE94B194C9AF67A09A84B878B
```

You will see that the you cannot assume this role because it does not exist. Now consider this role 
`arn:aws:iam::<AWS_ACCOUNT_NO>:role/<AWS_IAM_ROLE>` which actually exists and add a trust policy as follows:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::<AWS_ACCOUNT_NO>:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/C7F107CAE94B194C9AF67A09A84B878B"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "oidc.eks.us-west-2.amazonaws.com/id/C7F107CAE94B194C9AF67A09A84B878B:sub": [
                        "system:serviceaccount:domino-compute:domino-wadkars",
                        "system:serviceaccount:domino-compute:integration-test"
                    ]
                }
            }
        }
    ]
}
```

In the python shell now run the following
```python
import os
aws_account='<AWS_ACCOUNT_NO>'
aws_role='<AWS_IAM_ROLE>'
os.environ['AWS_ROLE_ARN']=f'arn:aws:iam::{aws_account}:role/{aws_role}'
import boto3.session
session = boto3.session.Session()
sts_client = session.client('sts')
sts_client.get_caller_identity()

{'UserId': 'AROA5YW464O6XT4444V43:botocore-session-1702067469', 'Account': '<AWS_ACCOUNT_NO>', 
 'Arn': 'arn:aws:sts::<AWS_ACCOUNT_NO>:assumed-role/<AWS_IAM_ROLE>/botocore-session-1702067469', 
 'ResponseMetadata': {'RequestId': '4bd490d2-74c7-4605-ae9e-9023d46dd979', 'HTTPStatusCode': 200,
                      'HTTPHeaders': {'x-amzn-requestid': '4bd490d2-74c7-4605-ae9e-9023d46dd979', 
                       'content-type': 'text/xml', 'content-length': '478', 'date': 'Fri, 08 Dec 2023 20:31:10 GMT'}, 
                       'RetryAttempts': 0}}
```
Now we have successfully assumed an existing role with the trust policy configured to allow assuming it by the K8s 
service account

> The annotation on the service account is only a hint for the webhook to apply the proper mutations. It does not
> change the trust policies on any roles. That process is external to EKS. The webhook only prepares the pod to assume
> AWS role by adding the projected service token (establish identity) and configure the environment variables to enable
> boto3 library to make connections
> 

