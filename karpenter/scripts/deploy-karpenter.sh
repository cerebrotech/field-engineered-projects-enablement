#! /bin/bash
set -x
set -e
kubectl create namespace karpenter
kubectl create -f \
    https://raw.githubusercontent.com/aws/karpenter/v0.28.0/pkg/apis/crds/karpenter.sh_provisioners.yaml
kubectl create -f \
    https://raw.githubusercontent.com/aws/karpenter/v0.28.0/pkg/apis/crds/karpenter.k8s.aws_awsnodetemplates.yaml
kubectl apply -f karpenter.yaml
