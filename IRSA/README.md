# Self Paced Enablement for IRSA

This is a self paced enablement for the [IAM ROLE TO SA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) 
(IRSA) [Field Engineered Solution](https://github.com/cerebrotech/IRSA_DOMINO).

This is alternative for Credential Propagation which does not include and AWS keys. This method uses the AWS Web Identity 
Token issued by an OIDC provider associated with your EKS cluster. On the AWS IAM side, it trusts this OIDC provider.

The IRSA service manipulates the trust relationships of the AWS roles being assumed by the domino user to trust the 
service accounts associated with each workload.

The purpose of this page is to perform a self paced enablement session from a Domino perspective. We will not be covering
the internals of how this process works. For those interested. the deep dive details of how this works is explained in the following blog articles-
- [IAM Roles of K8s Service Accounts Deep Dive](https://mjarosie.github.io/dev/2021/09/15/iam-roles-for-kubernetes-service-accounts-deep-dive.html)
- [EKS Pod Identity Webhook Deep Dive](https://blog.mikesir87.io/2020/09/eks-pod-identity-webhook-deep-dive/)


>The key feature of K8s which enables this capability is the concept of 
[service account token volume projection](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#serviceaccount-token-volume-projection)
The Service Account Token Volume Projection feature of Kubernetes allows projection of time and audience-bound 
service account tokens into Pods. This feature is used by some applications to enhance security when using service accounts. 
*These tokens are separate from the default K8s service account tokens used to connect to the K8s API Server and 
disabled for user pods in Domino*. These tokens are issued by the IAM OIDC Provider configured in the AWS cluster and
are trusted by the AWS IAM which is how these tokens can be used to assume the appropriate IAM roles for the Pod.


>The installed service runs with the identity of the instance IAM role which has the following policy attached
> ```json

## Basic setup

We are going to assume that [Prod Field Domino Deployment](https://prod-field.cs.domino.tech/) is for ficticious company 
called "Acme". Acme has two AWS Accounts:

1. AWS Account where EKS is deployed (946429944765)
2. AWS Account where the Acme corporate assets such as S3 buckets are maintained (524112250363)

In order to access data in AWS from Domino, a domino user will need to assume roles in the corporate account 
(524112250363). There is no requirement that there be two accounts. This setup works even in case of a single AWS Account



The Prod Field domino deployment has three organizations:
1. `irsa-iamrole-list-bucket`
2. `irsa-iamrole-read-bucket`
3. `irsa-irsa-iamrole-update-bucket`

By default we provide a very basic mapping mechanism between users and aws roles. This mapping mechanism allows a 
domino admin to add membership to AWS roles via adding them to a set of domino organizations. The current mapping between
domino organizations and AWS role in the asset account is shown below

| Domino Organization      | AWS Role in the assets account |
| ----------- | ----------- |
| `irsa-iamrole-list-bucket`      | arn:aws:iam::524112250363:role/acme-list-bucket-role       |
| `irsa-iamrole-read-bucket`   | arn:aws:iam::524112250363:role/acme-read-bucket-role        |
| `irsa-irsa-iamrole-update-bucket`   | arn:aws:iam::524112250363:role/acme-update-bucket-role        |

Adding or removing users based on org membership only takes effect when new workspaces startup. The existing workspaces
are unaffected. Alternatively as user can invoke `curl http://localhost:6003/refresh` for this change to be effected 
in the existing workspace.

**There is an existing project - [irsa-enablement](https://prod-field.cs.domino.tech/u/sameer_wadkar/irsa-enablement/overview) 
in prod-field which walks into more details on the roles setup. We suggest you use the workbook in that project to go 
through this enablement session**

Before you go further read the supporting readme document labeled [AWS_SETUP.md](AWS_SETUP.md). This describes the various
roles and buckets defined in each AWS Account. Refer back to this document as you walk through this enablement session.

## Lets Begin

First step to add yourself as a member to all of the following orgs in prod-field:
1. `irsa-iamrole-list-bucket`
2. `irsa-iamrole-read-bucket`
3. `irsa-irsa-iamrole-update-bucket`

We will be using the project [irsa-enablement](https://prod-field.cs.domino.tech/u/sameer_wadkar/irsa-enablement/overview).

If you are doing this in your own deployment, follow the instructions in the [main repo](https://github.com/cerebrotech/IRSA_DOMINO)

### Start the first workspace

In the Prod Field Domino go the project [irsa-enablement](https://prod-field.cs.domino.tech/u/sameer_wadkar/irsa-enablement/overview)
and start a workspace and open the notebook `enablement.ipynb`. Directly go to the section "What is a web identity token?".

### Verify the services are running

First let us verify that the IRSA backend service is running

```shell
!curl http://irsa-svc.domino-field/healthz
## This is the expected output
{'status': 'Healthy'}
```

Now verify that your side-car container is running
```shell
!curl http://localhost:6003/healthz
## This is the expected output
{'status': 'Healthy'}
```

## Web Identity Token

A Web Identity Token is how your workspace authenticates to AWS IAM. It is injected into your workspace via a `domsed` mutation.

```yaml
  - name: aws-user-token
    projected:
      defaultMode: 422
      sources:
      - serviceAccountToken:
          path: token
          expirationSeconds: 86400
          audience: sts.amazonaws.com
```

Note that this token expires every 24 hours. We can and should make this shorter in a production deploymen. K8s rotates
this token 5 mins prior to expiry. If this token is compromised the attacker can use it to assume roles in the AWS
account using just an `.aws/config` file which matches the one in the workspace from which this token was stolen.

The mutation also injects to AWS specific environment variables
1. AWS_WEB_IDENTITY_TOKEN_FILE
2. AWS_CONFIG_FILE

Now run `cat $AWS_WEB_IDENTITY_TOKEN_FILE` . You will see an output which looks like the following:

```shell
eyJhbGciOiJSUzI1NiIsImtpZCI6IjM2ZThiOWIwZmE5ZDkzMTAxNDE2ZTY4NTE4ZThlNmI4YWM5MDc2M2YifQ.eyJhdWQiOlsic3RzLmFtYXpvbmF3cy5jb20iXSwiZXhwIjoxNjg1MDMwNzM2LCJpYXQiOjE2ODQ5NDQzMzYsImlzcyI6Imh0dHBzOi8vb2lkYy5la3MudXMtd2VzdC0yLmFtYXpvbmF3cy5jb20vaWQvNjM3Nzc5OEY5RDkyREZDN0M5QzM4NzNCOERBMjdDNjgiLCJrdWJlcm5ldGVzLmlvIjp7Im5hbWVzcGFjZSI6ImRvbWluby1jb21wdXRlIiwicG9kIjp7Im5hbWUiOiJydW4tNjQ2ZDI3YjgxN2MyOGI1ZWE0YjViMGMxLWZ4YzJxIiwidWlkIjoiNjNlMzczYjAtNGQ2Mi00ODYwLWEzMjktYmFlYzFhZmNkM2Y4In0sInNlcnZpY2VhY2NvdW50Ijp7Im5hbWUiOiJydW4tNjQ2ZDI3YjgxN2MyOGI1ZWE0YjViMGMxIiwidWlkIjoiZWQ5N2NmY2YtNThjNi00YzFlLTg5MjktNzFmZjliYzMzNWFhIn19LCJuYmYiOjE2ODQ5NDQzMzYsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpkb21pbm8tY29tcHV0ZTpydW4tNjQ2ZDI3YjgxN2MyOGI1ZWE0YjViMGMxIn0.Kahf0Yig0g5588A64CNimAVzlPm2bIyd9IgIG-bqFCWDqwEc6pT-aU8K30XKf5rlvwgtUISvkYqxqCapMPd62awGV5n9rQXxWVni5f2FxjOXSJKgBY2wCex9bXmuFnts6DW0t3hUWSaNwSQx5lvqG8MuTxSbw2QHTqY34dVrpIltYyYAOwHHXXk-hwaOERgwBwhJxho_3fG7VbDj48x4W4ye6bGfnIis4ct3Q11SukLqcZAdrvagolBjcoBEZ9PYnyLyrKEUjFx6yIYLDjsMLsulOpBb_5-Lzbj2j5rp90dVHOawy21PkY4aeSdvS5Dus1d1rsFAR9IuSEtVnTJ-8A
```

Open the site www.jwt.io and past the above output. You will now see a JSON file which looks like this:

```json
{
  "aud": [
    "sts.amazonaws.com"
  ],
  "exp": 1685030736,
  "iat": 1684944336,
  "iss": "https://oidc.eks.us-west-2.amazonaws.com/id/6377798F9D92DFC7C9C3873B8DA27C68",
  "kubernetes.io": {
    "namespace": "domino-compute",
    "pod": {
      "name": "run-646d27b817c28b5ea4b5b0c1-fxc2q",
      "uid": "63e373b0-4d62-4860-a329-baec1afcd3f8"
    },
    "serviceaccount": {
      "name": "run-646d27b817c28b5ea4b5b0c1",
      "uid": "ed97cfcf-58c6-4c1e-8929-71ff9bc335aa"
    }
  },
  "nbf": 1684944336,
  "sub": "system:serviceaccount:domino-compute:run-646d27b817c28b5ea4b5b0c1"
}
```

Note the `iss`. This is the token that boto3 api uses to implicitly authenticate with IAM. This occurs implicitly when the `AWS_WEB_IDENTITY_TOKEN_FILE` environment variable set.

Note the `sub` is `system:serviceaccount:domino-compute:run-$DOMINO_RUN_ID` (your workspace service account is same as your run-id)
[Ex. `system:serviceaccount:domino-compute:run-646d27b817c28b5ea4b5b0c1`] 

`system:serviceaccount:domino-compute:run-646d27b817c28b5ea4b5b0c1` (your workspace service account) . This will be important later.

### AWS Config File

The `boto3` library looks for the config file in the following location `$AWS_CONFIG_FILE` which in your workspace
is set to `/var/run/.aws/config`

Run the following command

```shell
cat $AWS_CONFIG_FILE

## This will produce the following output

[profile acme-update-bucket-role]
source_profile = src_acme-update-bucket-role
role_arn=arn:aws:iam::524112250363:role/acme-update-bucket-role
[profile src_acme-update-bucket-role]
web_identity_token_file = /var/run/secrets/eks.amazonaws.com/serviceaccount/token
role_arn=arn:aws:iam::946429944765:role/acme-update-bucket-role
[profile acme-read-bucket-role]
source_profile = src_acme-read-bucket-role
role_arn=arn:aws:iam::524112250363:role/acme-read-bucket-role
[profile src_acme-read-bucket-role]
web_identity_token_file = /var/run/secrets/eks.amazonaws.com/serviceaccount/token
role_arn=arn:aws:iam::946429944765:role/acme-read-bucket-role
[profile acme-list-bucket-role]
source_profile = src_acme-list-bucket-role
role_arn=arn:aws:iam::524112250363:role/acme-list-bucket-role
[profile src_acme-list-bucket-role]
web_identity_token_file = /var/run/secrets/eks.amazonaws.com/serviceaccount/token
role_arn=arn:aws:iam::946429944765:role/acme-list-bucket-role
```
This is file is created by the side-car container during startup. You can always refresh it using the command 
```shell
curl http://localhost:6003/refresh
```

For each profile in the asset account there is a corresponding role in the eks account

| AWS Profile (Asset Account)     | SRC AWS Profile (EKS Account) |
| ----------- | ----------- |
| `acme-list-bucket-role`      | `src_acme-list-bucket-role`       |
| `acme-read-bucket-role`  | `src_acme-read-bucket-role`       |
| `acme-update-bucket-role`   | `src_acme-read-bucket-role`       |

An example `src` profile looks like this:

```shell
[profile src_acme-list-bucket-role]
web_identity_token_file = /var/run/secrets/eks.amazonaws.com/serviceaccount/token
role_arn=arn:aws:iam::946429944765:role/acme-list-bucket-role
```
The corresponding asset profile looks like this:

```shell
[profile acme-list-bucket-role]
source_profile = src_acme-list-bucket-role
role_arn=arn:aws:iam::524112250363:role/acme-list-bucket-role
```

When the user assumes the asset profile `acme-list-bucket-role` it knows its `source_profile` is `src_acme-list-bucket-role`

The `src_acme-list-bucket-role` uses the `web_identity_token_file` to authenticate with AWS IAM which already has 
a trust relationship established with the OIDC provider who issues the web identity token. It uses this to assume the role
`role_arn` in the source profile `aws:iam::946429944765:role/acme-list-bucket-role`

The `aws:iam::946429944765:role/acme-list-bucket-role` in turn tries to assume the role `arn:aws:iam::524112250363:role/acme-list-bucket-role`
which is listed as the `role_arn` in the `[profile acme-list-bucket-role]`

### Bringing it all together

When the workspace starts up, the side-car invokes the backend IRSA service using the following code-snippet

```python
#Emulate Side-Car
import requests
import os
access_token_endpoint='http://localhost:8899/access-token'
resp = requests.get(access_token_endpoint)


token = resp.text
headers = {
             "Content-Type": "application/json",
             "Authorization": "Bearer " + token,
        }
endpoint='http://irsa-svc.domino-field/map_iam_roles_to_pod_sa'
data = {"run_id": os.environ['DOMINO_RUN_ID']} ## It fetches this fom the downward api
resp = requests.post(endpoint,headers=headers,json=data)
resp.text
```

The backend IRSA service updates the trust policy file attached to each of the source roles being added to the config file.
The trust policy will look like this:
```json
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
                    "oidc.eks.us-west-2.amazonaws.com/id/6377798F9D92DFC7C9C3873B8DA27C68:sub": [
                        "*:domino-compute:run-646d27b817c28b5ea4b5b0c1",
                        "*:domino-compute:run-646f604955daf764547c5b77"
                    ]
                }
            }
        }
    ]
}
```
Note the `aud` and `sub` fields. This is the reason why the `src_acme-list-bucket-role` profile can assume the role
`arn:aws:iam::946429944765:role/acme-list-bucket-role`. If you remove the entries for your workspace from the trust policy,
the web identity token can authenticate with the AWS IAM but IAM will not allow it to assume the role.

Last each of the roles in the EKS Account have the following policies attached to them:

| Role    | Policies  |
| ----------- | ----------- |
| `acme-list-bucket-role`      | `acme-list-bucket-policy`       |
| `acme-read-bucket-role`  | `acme-read-bucket-policy`       |
| `acme-update-bucket-role`   | `acme-read-bucket-policy`       |

`acme-list-bucket-policy` looks like this:
```json
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
The other two policies are similar


To summarize two things make it possible for the workspace to assume the role `arn:aws:iam::946429944765:role/acme-list-bucket-role`
(and the other two roles):

1. The web identity token which was issued by the oidc provider (`sub` provides the identity)
2. The `Condition` section of the trust policy attached to the roles which explictly declares which `sub` are allowed to 
assume the role.
3. The permission policies attached to the roles in the EKS account will be allowed to assume roles in the Assets account.

One last thing, the corresponding roles in the Assets Account ex. `arn:aws:iam::524112250363:role/acme-list-bucket-role`
need to have their trust policy to allow principals in the EKS account to assume it. This is the trust policy attached to
each of the roles `acme-list-bucket-role` , `acme-read-bucket-role` and `acme-update-bucket-role` 

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::946429944765:root"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

### Now lets get some action

Let us actual make calls using the `boto3` api now :


### Listing Profiles

Let us use the boto3 library to fetch all the profiles available. This is similar to `cat $AWS_CONFIG_FILE`
```python

import boto3.session
for profile in boto3.session.Session().available_profiles:
    print(profile)
```
This should produce the following output

```shell
acme-update-bucket-role
src_acme-update-bucket-role
acme-read-bucket-role
src_acme-read-bucket-role
acme-list-bucket-role
src_acme-list-bucket-role
```

### Listing the bucket

First lets verify what the identity of the profile is. This is determines by a combination of the web identity token
and the underlying assumed role in the Assests Account via the role in the EKS Account

```python
import boto3.session
list_bucket_profile_name='acme-list-bucket-role'
session = boto3.session.Session(profile_name=list_bucket_profile_name)
sts_client = session.client('sts')
sts_client.get_caller_identity()
```
Note the ARN below `arn:aws:sts::524112250363:assumed-role/acme-list-bucket-role/botocore-session-1685023049`. It belongs to
the assets account.

```shell
{'UserId': 'AROAXUB4GIX5XGPXPJ522:botocore-session-1685023049',
 'Account': '524112250363',
 'Arn': 'arn:aws:sts::524112250363:assumed-role/acme-list-bucket-role/botocore-session-1685023049',
 'ResponseMetadata': {'RequestId': 'a77c680f-5197-490d-afdd-c679638c0e2b',
  'HTTPStatusCode': 200,
  'HTTPHeaders': {'x-amzn-requestid': 'a77c680f-5197-490d-afdd-c679638c0e2b',
   'content-type': 'text/xml',
   'content-length': '482',
   'date': 'Thu, 25 May 2023 13:57:30 GMT'},
  'RetryAttempts': 0}}
```

The following permission policy is attached to the role is `acme-list-bucket-policy` (only relevant snippet)

```json
        {
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": ["arn:aws:s3:::domino-acme-test-bucket"]
        }
```



Now list the bucket
```python
import boto3
test_bucket='domino-acme-test-bucket'
list_bucket_profile_name='acme-list-bucket-role'
session = boto3.session.Session(profile_name=list_bucket_profile_name)
s3_client = session.client('s3')
for key in s3_client.list_objects(Bucket=test_bucket)['Contents']:
    print(key)

```
This will list three objects in this bucket:
```shell
{'Key': 'a.txt', 'LastModified': datetime.datetime(2023, 5, 23, 21, 8, 28, tzinfo=tzlocal()), 'ETag': '"d41d8cd98f00b204e9800998ecf8427e"', 'Size': 0, 'StorageClass': 'STANDARD', 'Owner': {'DisplayName': 'ops+aws-domino-cs-eval', 'ID': 'c745a304f2b9d04fceed84743d0486eda1ca6aaef0a5a7b560ffbd66a16d8441'}}
{'Key': 'b.txt', 'LastModified': datetime.datetime(2023, 5, 23, 21, 8, 28, tzinfo=tzlocal()), 'ETag': '"d41d8cd98f00b204e9800998ecf8427e"', 'Size': 0, 'StorageClass': 'STANDARD', 'Owner': {'DisplayName': 'ops+aws-domino-cs-eval', 'ID': 'c745a304f2b9d04fceed84743d0486eda1ca6aaef0a5a7b560ffbd66a16d8441'}}
{'Key': 'c.txt', 'LastModified': datetime.datetime(2023, 5, 23, 21, 8, 27, tzinfo=tzlocal()), 'ETag': '"d41d8cd98f00b204e9800998ecf8427e"', 'Size': 0, 'StorageClass': 'STANDARD', 'Owner': {'DisplayName': 'ops+aws-domino-cs-eval', 'ID': 'c745a304f2b9d04fceed84743d0486eda1ca6aaef0a5a7b560ffbd66a16d8441'}}
```

### Writing to the bucket

Now we write to the bucket. For that we need to use the profile 'acme-update-bucket-role'. This role in the assets
account will have the following policies attached to it (List, Read, Update permission)

1. `acme-list-bucket-policy` [Only the relevant snipper below]


2. `acme-read-bucket-policy` 

```json
        {
            "Effect": "Allow",
            "Action": ["s3:Get*"],
            "Resource": ["arn:aws:s3:::domino-acme-test-bucket/*"]
        }
```

2. `acme-update-bucket-policy` 

```json
     [
        {
            "Sid": "WriteObjectsInBucket",
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": ["arn:aws:s3:::domino-acme-test-bucket/*"]
        },
        {
            "Sid": "DeleteObjectsInBucket",
            "Effect": "Allow",
            "Action": "s3:DeleteObject",
            "Resource": ["arn:aws:s3:::domino-acme-test-bucket/*"]
        }
    ]
```

Now let us create a object with key `$DOMINO_STARTING_USERNAME.txt`

```python
import boto3
import os
test_bucket='domino-acme-test-bucket'
starting_user = os.environ['DOMINO_STARTING_USERNAME']
update_bucket_profile_name='acme-update-bucket-role'
session = boto3.session.Session(profile_name=update_bucket_profile_name)
s3_client = session.client('s3')
object_data = "This is a random string."
object_key = f'{starting_user}.txt'
s3_client.put_object(Body=object_data, Bucket=test_bucket, Key=object_key)
```

Listing the bucket now will return the following results (Expect the key with your domino user name). 

```shell
{'Key': 'a.txt', 'LastModified': datetime.datetime(2023, 5, 23, 21, 8, 28, tzinfo=tzlocal()), 'ETag': '"d41d8cd98f00b204e9800998ecf8427e"', 'Size': 0, 'StorageClass': 'STANDARD', 'Owner': {'DisplayName': 'ops+aws-domino-cs-eval', 'ID': 'c745a304f2b9d04fceed84743d0486eda1ca6aaef0a5a7b560ffbd66a16d8441'}}
{'Key': 'b.txt', 'LastModified': datetime.datetime(2023, 5, 23, 21, 8, 28, tzinfo=tzlocal()), 'ETag': '"d41d8cd98f00b204e9800998ecf8427e"', 'Size': 0, 'StorageClass': 'STANDARD', 'Owner': {'DisplayName': 'ops+aws-domino-cs-eval', 'ID': 'c745a304f2b9d04fceed84743d0486eda1ca6aaef0a5a7b560ffbd66a16d8441'}}
{'Key': 'c.txt', 'LastModified': datetime.datetime(2023, 5, 23, 21, 8, 27, tzinfo=tzlocal()), 'ETag': '"d41d8cd98f00b204e9800998ecf8427e"', 'Size': 0, 'StorageClass': 'STANDARD', 'Owner': {'DisplayName': 'ops+aws-domino-cs-eval', 'ID': 'c745a304f2b9d04fceed84743d0486eda1ca6aaef0a5a7b560ffbd66a16d8441'}}
{'Key': 'sameer_wadkar.txt', 'LastModified': datetime.datetime(2023, 5, 25, 17, 13, 38, tzinfo=tzlocal()), 'ETag': '"33574c5c39e1f40f425e237b474f2da5"', 'Size': 24, 'StorageClass': 'STANDARD', 'Owner': {'DisplayName': 'ops+aws-domino-cs-eval', 'ID': 'c745a304f2b9d04fceed84743d0486eda1ca6aaef0a5a7b560ffbd66a16d8441'}}
```

If you try to read the key using this role using the code below
```python
import boto3
import os
test_bucket='domino-acme-test-bucket'
starting_user = os.environ['DOMINO_STARTING_USERNAME']
update_bucket_profile_name='acme-update-bucket-role'
object_key = f'{starting_user}.txt'
session = boto3.session.Session(profile_name=update_bucket_profile_name)
s3_client = session.client('s3')
data = s3_client.get_object(Bucket=test_bucket, Key=object_key)
contents = data['Body'].read()

print(f'\n---Contents of the key {object_key}----\n')
print(contents.decode("utf-8"))
```

You will see an error indicating that the role does not have `GetObject` operation allowed for it.
```shell
ClientError: An error occurred (AccessDenied) when calling the GetObject operation: Access Denied
```

### Reading a key from the bucket

Let us now read the newly added object from the bucket. This is provided by the role `acme-read-bucket-role`. This role
has the  policies `acme-read-bucket-policy` attached to it:

1. `acme-list-bucket-policy`
2. `acme-read-bucket-policy`
```json
         {
            "Sid": "WriteObjectsInBucket",
            "Effect": "Allow",
            "Action": ""s3:Get*"",
            "Resource": ["arn:aws:s3:::domino-acme-test-bucket/*"]
        }
```

Run the following code snippet:

```python

import boto3
import os
test_bucket='domino-acme-test-bucket'
starting_user = os.environ['DOMINO_STARTING_USERNAME']
read_bucket_profile_name='acme-read-bucket-role'
object_key = f'{starting_user}.txt'
session = boto3.session.Session(profile_name=read_bucket_profile_name)
s3_client = session.client('s3')
data = s3_client.get_object(Bucket=test_bucket, Key=object_key)
contents = data['Body'].read()
print(f'\n---Contents of the key {object_key}----\n')
print(contents.decode("utf-8"))
```

This produces the output

```shell
---Contents of the key sameer_wadkar.txt----

This is a random string.
```

### Deleting a key from the bucket

Finally let us delete the newly created object

```python
import boto3
import os
test_bucket='domino-acme-test-bucket'
update_bucket_profile_name='acme-update-bucket-role'
starting_user = os.environ['DOMINO_STARTING_USERNAME']
object_key = f'{starting_user}.txt'
print(f'Deleting Key {object_key} from bucket {test_bucket}')

session = boto3.session.Session(profile_name=update_bucket_profile_name)
s3_client = session.client('s3')
s3_client.delete_object(Bucket=test_bucket, Key=object_key)
print('\nNow listing bucket:\n')
for key in s3_client.list_objects(Bucket=test_bucket)['Contents']:
    print(key)


```

This produces the following output

```shell
Deleting Key sameer_wadkar.txt from bucket domino-acme-test-bucket

Now listing bucket:

{'Key': 'a.txt', 'LastModified': datetime.datetime(2023, 5, 23, 21, 8, 28, tzinfo=tzlocal()), 'ETag': '"d41d8cd98f00b204e9800998ecf8427e"', 'Size': 0, 'StorageClass': 'STANDARD', 'Owner': {'DisplayName': 'ops+aws-domino-cs-eval', 'ID': 'c745a304f2b9d04fceed84743d0486eda1ca6aaef0a5a7b560ffbd66a16d8441'}}
{'Key': 'b.txt', 'LastModified': datetime.datetime(2023, 5, 23, 21, 8, 28, tzinfo=tzlocal()), 'ETag': '"d41d8cd98f00b204e9800998ecf8427e"', 'Size': 0, 'StorageClass': 'STANDARD', 'Owner': {'DisplayName': 'ops+aws-domino-cs-eval', 'ID': 'c745a304f2b9d04fceed84743d0486eda1ca6aaef0a5a7b560ffbd66a16d8441'}}
{'Key': 'c.txt', 'LastModified': datetime.datetime(2023, 5, 23, 21, 8, 27, tzinfo=tzlocal()), 'ETag': '"d41d8cd98f00b204e9800998ecf8427e"', 'Size': 0, 'StorageClass': 'STANDARD', 'Owner': {'DisplayName': 'ops+aws-domino-cs-eval', 'ID': 'c745a304f2b9d04fceed84743d0486eda1ca6aaef0a5a7b560ffbd66a16d8441'}}
```

### Internals of the IRSA Service:  Who updates the trust policy for the roles in the EKS Account

All this magic is made possible because everytime a workspace comes up, the IRSA service looks up the organization group 
membership of the Domino user and identifies what roles they can assume. It then updates the trust policy of the role.

All the three roles below:

1. `arn:aws:iam::946429944765:role/acme-list-bucket-role`
2. `arn:aws:iam::946429944765:role/acme-read-bucket-role`
3. `arn:aws:iam::946429944765:role/acme-update-bucket-role`

have their trust policies to allow the workspace service account as defined in the `sub` field of the token in the 
`$AWS_WEB_IDENTITY_TOKEN_FILE` to assume them.
```json

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
                    "oidc.eks.us-west-2.amazonaws.com/id/6377798F9D92DFC7C9C3873B8DA27C68:sub": [
                        "*:domino-compute:run-646d27b817c28b5ea4b5b0c1",
                        "*:domino-compute:run-646f604955daf764547c5b77"
                    ],
                    "oidc.eks.us-west-2.amazonaws.com/id/6377798F9D92DFC7C9C3873B8DA27C68:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
```

The main question is **HOW DOES THE IRSA SERVICE HAVE PERMISSIONS TO UPDATE THE TRUST POLICIES OF THESE ROLES?**

The reason is the IRSA service runs unders the K8s service account `system:serviceaccount:domino-field:irsa` with mounted
projected service account token which can assume the IAM Role `arn:aws:iam::946429944765:role/acme-irsa-svc-role` which has
a trust policy below 
```json
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

The role is attached a permission policy `acme-irsa-svc-policy` which has the following permissions

```json
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
The projected service account token is mounted in this pod to provide it an identity via the OIDC provider of the EKS cluster
by the IRSA AWS webhook by reading the service account annotation `eks.amazonaws.com/role-arn` for this deployment 
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::946429944765:role/acme-irsa-svc-role
  name: irsa
  namespace: domino-field
```

Note that the trust policy of the role already permits this service account to assume itself.

This should explain why the IRSA pod can update the trust policies of the roles `acme-list-bucket-role`, `acme-read-bucket-role`
and the `acme-update-bucket-role`.

### Do I have to restart my workspace to update the AWS_CONFIG_FILE

No you don't have to restart the workspace. Although that will work you can simply make the call below to update the
config file. 

```shell
curl http://127.0.0.1:6003/refresh 
```
The side car will invoke the irsa service, fetch the latest role mappings and update the file `$AWS_CONFIG_FILE`

Internally the side-car does the following:
```python
#Emulate Side-Car
import requests
import os
access_token_endpoint='http://localhost:8899/access-token'
resp = requests.get(access_token_endpoint)


token = resp.text
headers = {
             "Content-Type": "application/json",
             "Authorization": "Bearer " + token,
        }
endpoint='http://irsa-svc.domino-field/map_iam_roles_to_pod_sa'
data = {"run_id": os.environ['DOMINO_RUN_ID']}
resp = requests.post(endpoint,headers=headers,json=data)
resp.text #The output that it writes to the AWS_CONFIG_FILE
```
Inside the side-car the environment variable `DOMINO_RUN_ID` is not available. Instead it uses the K8s Downward API to
mount a volume with pod labels which it uses to fetch the `DOMINO_RUN_ID`

## Debugging

This section will outline all the things that can go wrong and how to identify and resolve them.

### The Workload does not have the side-car container added to it

A lot of action happens in the side-car container `aws-config-file-generator` added via a mutation. If this container
is not added, irsa will not work. As a workaround you can make the calls below and create a new $AWS_CONFIG_FILE and update
the environment variable and irsa could still work. 

```python
import requests
import os
access_token_endpoint='http://localhost:8899/access-token'
resp = requests.get(access_token_endpoint)


token = resp.text
headers = {
             "Content-Type": "application/json",
             "Authorization": "Bearer " + token,
        }
endpoint='http://irsa-svc.domino-field/map_iam_roles_to_pod_sa'
data = {"run_id": os.environ['DOMINO_RUN_ID']}
resp = requests.post(endpoint,headers=headers,json=data)
resp.text #The output that it writes to the AWS_CONFIG_FILE
```
But that still assumes that the `$AWS_WEB_IDENTITY_TOKEN_FILE` is mounted.
If the mutation does not run, this token won't be mounted and the boto3 calls will not succeed even if the aws config file
is created. 

1. First check if the mutations are installed
```shell
kubectl -n domino-platform get mutations | grep irsa
```

2. If mutations are installed, check if the domsed mutating webhook is applying the mutations (This is in the operator webhook logs).
If not, restart the domsed webhook.
   
```shell
kubectl -n domino-platform scale operator-webhook --replicas=0
kubectl -n domino-platform scale operator-webhook --replicas=1
```

### The IAM Role attached to the IRSA service does not have the appropriate IAM privileges

1. We will simulate this error by going to the `arn:aws:iam::946429944765:policy/acme-irsa-svc-policy` and removing the 
permission `UpdateAssumeRolePolicy` 

2. Now start a new workspace

You will find that the `$AWS_CONFIG_FILE` does not exist in your workspace. 

Check the logs `/var/log/irsa/app.log` . In all likelihood
you will see a 500 error
```shell
2023-05-25 18:18:29,481 - werkzeug - DEBUG - Error Message from IRSA Endpoint: <!doctype html>
<html lang=en>
<title>500 Internal Server Error</title>
<h1>Internal Server Error</h1>
<p>The server encountered an internal error and was unable to complete your request. Either the server is overloaded or there is an error in the application.</p>
```

We are working to get better errors returned. But in the meantime go to the `irsa` service pod  in the `domino-field` 
namespace and tail the log `tail -f /var/log/irsa/app.log`

```shell
kubectl -n domino-field get pods | grep irsa
#Get the irsa pod id
kubectl -n domino-field exec -it irsa-759cccc4bd-2vf2v    -- cat /var/log/irsa/app.log 
```

You will see the following logs
```shell
2023-05-25 18:18:29,479 - botocore.parsers - DEBUG - Response body:
b'<ErrorResponse xmlns="https://iam.amazonaws.com/doc/2010-05-08/">\n  <Error>\n    <Type>Sender</Type>\n    <Code>AccessDenied</Code>\n    <Message>User: arn:aws:sts::946429944765:assumed-role/acme-irsa-svc-role/botocore-session-1685022987 is not authorized to perform: iam:UpdateAssumeRolePolicy on resource: role acme-update-bucket-role because no identity-based policy allows the iam:UpdateAssumeRolePolicy action</Message>\n  </Error>\n  <RequestId>7cd53494-85de-4695-942a-3b75b9564efe</RequestId>\n</ErrorResponse>\n'
2023-05-25 18:18:29,479 - botocore.hooks - DEBUG - Event needs-retry.iam.UpdateAssumeRolePolicy: calling handler <botocore.retryhandler.RetryHandler object at 0x7f4df7c243d0>
2023-05-25 18:18:29,479 - botocore.retryhandler - DEBUG - No retry needed.
2023-05-25 18:18:29,479 - botocore.hooks - DEBUG - Event after-call.iam.UpdateAssumeRolePolicy: calling handler <function json_decode_policies at 0x7f4df84a21f0>
2023-05-25 18:18:29,479 - irsa_service - ERROR - Exception on /map_iam_roles_to_pod_sa [POST]
Traceback (most recent call last):
  File "/home/app/lib/python3.8/site-packages/flask/app.py", line 2190, in wsgi_app
    response = self.full_dispatch_request()
  File "/home/app/lib/python3.8/site-packages/flask/app.py", line 1486, in full_dispatch_request
    rv = self.handle_user_exception(e)
  File "/home/app/lib/python3.8/site-packages/flask/app.py", line 1484, in full_dispatch_request
    rv = self.dispatch_request()
  File "/home/app/lib/python3.8/site-packages/flask/app.py", line 1469, in dispatch_request
    return self.ensure_sync(self.view_functions[rule.endpoint])(**view_args)
  File "/irsa/irsa_service.py", line 107, in map_iam_roles_to_aws_sa
    aws_utils.map_iam_roles_to_pod(
  File "/irsa/aws_utils.py", line 235, in map_iam_roles_to_pod
    self._iam.update_assume_role_policy(
  File "/home/app/lib/python3.8/site-packages/botocore/client.py", line 530, in _api_call
    return self._make_api_call(operation_name, kwargs)
  File "/home/app/lib/python3.8/site-packages/botocore/client.py", line 964, in _make_api_call
    raise error_class(parsed_response, operation_name)
botocore.exceptions.ClientError: An error occurred (AccessDenied) when calling the UpdateAssumeRolePolicy operation: User: arn:aws:sts::946429944765:assumed-role/acme-irsa-svc-role/botocore-session-1685022987 is not authorized to perform: iam:UpdateAssumeRolePolicy on resource: role acme-update-bucket-role because no identity-based policy allows the iam:UpdateAssumeRolePolicy action

```

Note the error which clearly indicates that the iam role `acme-irsa-svc-role` attached to the IRSA service pod does not 
have `iam:UpdateAssumeRolePolicy` on a corresponding role ex. `acme-update-bucket-role`
```shell
botocore.exceptions.ClientError: An error occurred (AccessDenied) when calling the UpdateAssumeRolePolicy operation: User: arn:aws:sts::946429944765:assumed-role/acme-irsa-svc-role/botocore-session-1685022987 is not authorized to perform: iam:UpdateAssumeRolePolicy on resource: role acme-update-bucket-role because no identity-based policy allows the iam:UpdateAssumeRolePolicy action
```

3. Let us fix this. Got back to the `arn:aws:iam::946429944765:policy/acme-irsa-svc-policy` and add the permission
 `UpdateAssumeRolePolicy` 
   
4. From inside the workspace run `curl http://127.0.0.1:6003/refresh` and check if the file `$AWS_CONFIG_FILE` exists
```shell
cat $AWS_CONFIG_FILE
```

The file should exist and be populated.

### The IAM Role in the EKS account does not have the Assume Role permission in the Assets account

Go to the role `arn:aws:iam::946429944765:role/acme-list-bucket-role` and remove the permission 
`arn:aws:iam::946429944765:role/acme-list-bucket-policy` attached to it.

Run the following code
```python
import boto3
list_bucket_profile_name='acme-list-bucket-role'
session = boto3.session.Session(profile_name=list_bucket_profile_name)
sts_client = session.client('sts')
sts_client.get_caller_identity()
```

and you will see the error
```shell
ClientError: An error occurred (AccessDenied) when calling the AssumeRole operation: User: arn:aws:sts::946429944765:assumed-role/acme-list-bucket-role/botocore-session-1685039715 is not authorized to perform: sts:AssumeRole on resource: arn:aws:iam::524112250363:role/acme-list-bucket-role
```

The error clearly mentions that the user session `User: arn:aws:sts::946429944765:assumed-role/acme-list-bucket-role/botocore-session-1685039715`
does not have AssumeRole privileges on `User: arn:aws:sts::946429944765:assumed-role/acme-list-bucket-role/botocore-session-1685039715`

Let us fix it

Got to the role `arn:aws:iam::946429944765:role/acme-list-bucket-role` and add the permission 
`arn:aws:iam::946429944765:role/acme-list-bucket-policy` back again.

Run this code again

```python
import boto3
list_bucket_profile_name='acme-list-bucket-role'
session = boto3.session.Session(profile_name=list_bucket_profile_name)
sts_client = session.client('sts')
sts_client.get_caller_identity()
```
And this will now succeed with an output which looks like this

```shell
{'UserId': 'AROAXUB4GIX5XGPXPJ522:botocore-session-1685041376',
 'Account': '524112250363',
 'Arn': 'arn:aws:sts::524112250363:assumed-role/acme-list-bucket-role/botocore-session-1685041376',
 'ResponseMetadata': {'RequestId': '368e8d98-1ea3-43f3-afac-137abd536b84',
  'HTTPStatusCode': 200,
  'HTTPHeaders': {'x-amzn-requestid': '368e8d98-1ea3-43f3-afac-137abd536b84',
   'content-type': 'text/xml',
   'content-length': '482',
   'date': 'Thu, 25 May 2023 19:02:56 GMT'},
  'RetryAttempts': 0}}

```


### Update the trust policy of the Assets account to remove principal from EKS Accounts to assume it

In the Assets Account go to the role `arn:aws:iam::524112250363:role/acme-list-bucket-role` and update the 
trust relationship as follows:
```yaml
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::524112250363:root"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```
We have replaced the AWS Account no from `946429944765` to `524112250363`

Run this code:

```python
import boto3
list_bucket_profile_name='acme-list-bucket-role'
session = boto3.session.Session(profile_name=list_bucket_profile_name)
sts_client = session.client('sts')
sts_client.get_caller_identity()
```

You should see the following error which clearly indicates that the principal `arn:aws:sts::946429944765:assumed-role/acme-list-bucket-role/botocore-session-1685043112`
is not allowed to assume the corresponding role in the `524112250363` account

```shell
An error occurred (AccessDenied) when calling the AssumeRole operation: User: arn:aws:sts::946429944765:assumed-role/acme-list-bucket-role/botocore-session-1685043112 is not authorized to perform: sts:AssumeRole on resource: arn:aws:iam::524112250363:role/acme-list-bucket-role
```
Let us fix it. Change the trust relationship for the role `arn:aws:iam::524112250363:role/acme-list-bucket-role`  
back to
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::946429944765:root"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}

and run the same code above again. It succeeds.

## Conclusion

This tutorial covers the full enablement for the IRSA project. The latter section also covers a section for the
Support Team to understand the reported errors and steps to debug and resolve them.