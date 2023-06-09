# 🕊️️ Self Paced Enablement for Domsed  🕊️️ ️️️️ 

Follow this page for performing a self paced enablement on Domsed. 

## Expected Outcomes

By the end of this tutorial you will be able to -

1. Install Domsed
2. Debug Domsed 
3. Create a brand new mutation in Domsed

### Step 1 - Start a Domino Cluster (Or reuse an existing one)

Start your own Domino instance and be able to `tsh` into it and perform `kubectl` command on the cluster

### Step 2 - Clone the Domsed repo lcoally

The domsed repo can be accessed at https://github.com/cerebrotech/domsed/

### Step 3 - Install Domsed in your Domino installation

Follow the steps outlined in the following installation [README](https://github.com/cerebrotech/domsed/blob/master/install/README_INSTALL.md)

## Debugging Domsed - Common problems

This is a list of common problems you will encounter when you work with domsed

### Installed Domsed by mutations are not applying

The most likely cause of this problem is that the `operator-webhook` deployment was not successfully deployed

```shell
platform_namespace="${platform_namespace:-domino-platform}"
compute_namespace="${compute_namespace:-domino-compute}"
```
```shell
kubectl -n ${platform_namespace} describe deployment operator-webhook
```


If you see that zero pods are running for this deployment identify what may have happened by inspecting the pod
```shell
kubectl -n ${platform_namespace} get pod | grep operator-webhook
# Get pod id
kubectl -n ${platform_namespace} describe pod $pod_id
```

Typical problems are related to image not being able to deploy for a variety of reasons. 

### Operator Webhook is running but mutation is not getting applied

You have confirmed that the operator webhook is now running. But the mutations are not getting applied

1. First confirm that the mutation is deployed. If not deploy it.
```shell
kubectl -n ${platform_namespace} get mutations
```

2. Mutation is applied but the mutation is still not getting applied

Now is the time to dig deeper and for that we need to look at the operator-webhook logs

```shell
kubectl -n ${platform_namespace} logs -f $pod_id
```

Two things may be the cause of this problem -

1. If you see errors, it is most likely that mutation threw an exception and domsed is designed to deploy the pod unmutated

2. If you do not see errors then one of the two things are happening - 
   
    a. Your cluster has istio enabled and when you installed you did not change the `values.yaml` for helm install to say istio is enabled
   
    b. The network policies are preventing access to the `operator-webhook` 
      - At Verizon on GKE the network policy `operator-webhook` had to be deleted. Back it up and verify it the mutation is applied
      - At Verizon on GKE the network policy `domino-ingress` does not allow domsed to work. Deleting has no adverse effects. Delete it and confirm mutation works



## Create a simple mutation

Follow the mutation `terminationGracePeriodSeconds` and create a new mutation with update `restartPolicy`  

Some of the files that may need to be changed -

1. Update the file `domsed/webhook.py`
2. Add a new python mutation to `domsed/mutation/customer_specific` (Use `domsed/mutation/customer_specific\tgp_secs_update.py` as a template)
3. Update the CRD `helm\domsed\templates\CustomResourceDefinition.yaml`
4. Possibly `helm\domsed\values.yaml`


### More Advanced Stuff

#### How does a mutating webhook work?

Review file `./helm/domsed/mutation.yaml` and understand how a `MutatingWebhookConfiguration` is configured

How does the configuration mark the type of resources being watched and how do you add to those types?

#### What is the role of the ServiceAccount for the Webhook?

Review the file `./helm/domsed/serviceaccount.yaml`, `./helm/domsed/role.yaml` and `helm/domsed/rolebinding.yaml` 
and correlate that to the operator-webhook deployment code `./domsed/webhook.py`

#### If there are multiple mutating webhooks what is the order in which they apply?

[Alphabetical](https://www.reddit.com/r/kubernetes/comments/g864zf/is_there_a_way_to_change_the_triggering_order_of/) order of their names. You can control the order by changing their names. But it is not the 
best idea. Instead use the `Reinvocation Policy` [capability](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#reinvocation-policy)

#### If the mutation throws and error will my workspace/workload fail?

No. The mutation will not be applied. The [Failure Policy](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#reinvocation-policy) is set to `Ignore` 


## ADD YOUR OWN FINDINGS AND EXTEND THIS PAGE

Please feel free to contribute with your own findings. 




