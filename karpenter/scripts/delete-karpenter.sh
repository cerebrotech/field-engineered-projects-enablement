#! /bin/bash
set -x
set -e
kubectl delete -f \
    https://raw.githubusercontent.com/aws/karpenter/v0.24.0/pkg/apis/crds/karpenter.sh_provisioners.yaml -n karpenter
kubectl delete -f \
    https://raw.githubusercontent.com/aws/karpenter/v0.24.0/pkg/apis/crds/karpenter.k8s.aws_awsnodetemplates.yaml -n karpenter
kubectl delete -f karpenter.yaml 
kubectl delete ns karpenter
