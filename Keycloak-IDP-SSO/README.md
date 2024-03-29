# 🕊️  Self Paced Enablement for configuring SSO for your own Domino using Keycloak as an IDP 🕊️

## Pre-requisites

### Configure SSH Keys for your Github Account

1. Create ssh keys
```shell
ssh-keygen -t ed25519 -C "<YOUREMAILID>r@dominodatalab.com"
#This will produce the ssh key in the following folder. 
$HOME/.ssh/id_ed25519
$HOME/.ssh/id_ed25519.pub
```

2. Fetch and Copy the contents of the `$HOME/.ssh/id_ed25519.pub`
```shell
cat $HOME/.ssh/id_ed25519.pub
```

Configure this as an SSH Key in your Github Account's page and for that key configure SSO for the `cerebrotech` organization

<img src="https://github.com/cerebrotech/field-engineered-projects-enablement/blob/main/images/configure-sso-for-cerebrotech.png"/>

3. In your Domino deployment, add the following keys to central config
```shell
com.cerebro.domino.auth.aws.sts.enabled                 true
com.cerebro.domino.auth.aws.sts.region                  us-west-2
com.cerebro.domino.auth.aws.sts.defaultSessionDuration  1h
```
Restart services so that the changes take effect.


### Configure the AWS Environment

Create access keys for an Administrator user and configure your own aws environment. This page assumes these keys are configured in your `default` profile 

Alternatively run the following commands in the shell where your will run this tutorial
```shell
export AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY_ID>
export AWS_SECRET_ACCESS_KEY=<AWS_SECRET_ACCESS_KEY>
```

## Download the `platform-apps` project

```shell
mkdir $HOME/domino-sso
git clone git@github.com:cerebrotech/platform-apps.git
```


## Create a python virtual environment

I used Python 3.11 for testing
```shell
cd  $HOME/domino-sso/platform-apps-develop/
##My $PYTHON_BIN is /Users/sameerwadkar/Library/Python/3.11/bin/
# export PYTHON_BIN=/Users/sameerwadkar/Library/Python/3.11/bin/
$PYTHON_BIN/pipenv shell
#Start shell within the environment
$PYTHON_BIN/pipenv shell

#Sync the contents of the Pipfile.lock into this environment
$PYTHON_BIN/pipenv sync 

##If you ever need to exit your env type - "exit" on the command line to exit the virtual env shell
```

If you're using an older version of python (for example 3.8), then the command is
```shell
cd  $HOME/domino-sso/platform-apps-develop/
python3 -m pipenv --python 3.8 shell
```


## Point to your Domino Cluster

```shell
export ps=domino-platform
export DOMINO_USERHOST=https://swdemo22449.cs.domino.tech/
export DOMINO_KEYCLOAK_PASSWORD=$(kubectl get secret -n $ps keycloak-http -o jsonpath='{.data.password}' | base64 --decode && echo)
export IDP_HOST_URL=https://swdemo22449.cs.domino.tech/
export IDP_KEYCLOAK_PASSWORD=$(kubectl get secret -n $ps keycloak-http -o jsonpath='{.data.password}' | base64 --decode && echo)
 ```

## Configure SSO

```shell
./src/ops/configure-sso-with-standalone-keycloak.py configure-sso

## You will see output like the following
Creating new IDP Realm if it does not exist: SamlRealm
Creating AWS resources
Creating identity provider...
Creating role...
Updating trusted entities for created role...
Retry 1 of 10...
Creating and attaching policies...
Creating new client: DominoRealm/auth/realms/DominoRealm in realm: SamlRealm
Creating and configuring IDP in Domino Instance
Adding mappers to IDP in Domino Instance
Enabling roles synchronization
Domino Instance: https://swdemo22449.cs.domino.tech SSO configuration completed
```

If you head over to your AWS console you will find the following AWS resources created (based on your domino instance id)

```shell
swdemo22449-SamlRealm-saml-policy (Policy)
swdemo22449-SamlRealm-saml-role@a.b (Role)
swdemo22449-SamlRealm-saml-provider (SAML Provider)
```

In your Keycloak you will also find that a `SAMLRealam` is created and an Identity Provider under the `DominoRealm` with a name similar to
`Keycloak-IDP-swdemo22449-7eNe` (Based on your Domino Instance Id)

Inside your `SAMLRealm` you will find the following users 
1. `integration-test`
2. `project-manager`
3. `results-consumer-user`
4. `selenium-test-user`
5. `system-test`

Open the file `./src/ops/configure-sso-with-standalone-keycloak.py` to find out their roles and passwords

## Test Credential Propagation

Credential propagation is automatically enabled. Start a workspace and run the following in a terminal

```shell
$ env | grep AWS
AWS_SHARED_CREDENTIALS_FILE=/var/lib/domino/home/.aws/credentials
$ cat $AWS_SHARED_CREDENTIALS_FILE
[swdemo22449-SamlRealm-saml-role_a_b]
aws_access_key_id = aaaa
aws_secret_access_key = xxxx
aws_session_token = zzzz

$ aws sts get-caller-identity --profile swdemo22449-SamlRealm-saml-role_a_b
{
    "UserId": "aaaa:integration-test@dominodatalab.com",
    "Account": "<AWS_ACCOUNT_ID>",
    "Arn": "arn:aws:sts::<AWS_ACCOUNT_ID>:assumed-role/swdemo22449-SamlRealm-saml-role@a.b/integration-test@dominodatalab.com"
}
```


## De-Configure SSO

```shell
./src/ops/configure-sso-with-standalone-keycloak.py de-configure-sso

### You will see output as follows
Deleting AWS resources
Logging out of all DominoRealm sessions
Deleting IDP Keycloak-IDP-swdemo22449-5JVU in Domino Instance
Deleting corresponding client https://swdemo22449.cs.domino.tech/auth/realms/DominoRealm in IDP
Domino Instance: https://swdemo22449.cs.domino.tech SSO de-configuration completed
```

## Troubleshooting

1. The security token included in the request is invalid.
```shell
Creating new IDP Realm if it does not exist: SamlRealm
Creating AWS resources
Creating identity provider...
Traceback (most recent call last):
  File "./src/ops/configure-sso-with-standalone-keycloak.py", line 819, in <module>
    ManageTestSSO.from_shell(sys.argv[1:])
  File "./src/ops/configure-sso-with-standalone-keycloak.py", line 188, in from_shell
    manager.execute()
  File "./src/ops/configure-sso-with-standalone-keycloak.py", line 193, in execute
    self.opts.func()
  File "/Users/akshayambekar/domino-sso/platform-apps-develop/src/common/scripting.py", line 172, in run_func
    return func(*args, **kwargs)
  File "./src/ops/configure-sso-with-standalone-keycloak.py", line 226, in configure_sso
    iam_resources = self.create_iam_resources(
  File "./src/ops/configure-sso-with-standalone-keycloak.py", line 702, in create_iam_resources
    saml_provider = iam_client.create_saml_provider(
  File "/Users/akshayambekar/.local/share/virtualenvs/platform-apps-develop-Gx-l9uqE/lib/python3.8/site-packages/botocore/client.py", line 535, in _api_call
    return self._make_api_call(operation_name, kwargs)
  File "/Users/akshayambekar/.local/share/virtualenvs/platform-apps-develop-Gx-l9uqE/lib/python3.8/site-packages/botocore/client.py", line 980, in _make_api_call
    raise error_class(parsed_response, operation_name)
botocore.exceptions.ClientError: An error occurred (InvalidClientTokenId) when calling the CreateSAMLProvider operation: The security token included in the request is invalid.
```

Root cause: Incorrect/Invalid AWS Access Key Id and Secret Key
Resolution: Add the correct AWS Access Key and Secret Key

2. No module named 'common.logging'
```shell
(platform-apps-develop) ➜  platform-apps-develop ./src/ops/configure-sso-with-standalone-keycloak.py configure-sso                           
Traceback (most recent call last):
  File "./src/ops/configure-sso-with-standalone-keycloak.py", line 20, in <module>
    from common.logging import add_logging_args, logger, setup_script_logging
ModuleNotFoundError: No module named 'common.logging'
```

The code in the file that you're executing relies on [this common package](https://github.com/cerebrotech/platform-python-common/tree/develop/common) from the platform-python-common repo. Make sure this repo is pulled in case the pipenv doesn't automatically resolve the common.logging error

3. No credentials found in workspace
Run the below mongodb query
```shell
db.user_session_values.find({"principalId": ObjectId("<user id in question>")});
```

The output should contain `aws` as a value for the `credentials` key
```shell
{
	"_id" : ObjectId("64e7a6f95d62a8eb4eead5e7"),
	"principalId" : ObjectId("64e7a6f8cc10507b1746031e"),
	"key" : "must-have",
	"values" : {
		"credentials" : "jwt|aws"
	}
}
```
If that's missing, then that means Domino is not invoking the AssumeRoleWithSAML call. Make sure you've performed step 3 under Pre-requisites and restarted services.`
