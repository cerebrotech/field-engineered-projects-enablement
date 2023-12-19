

module "irsa_proxy_role1" {
    source = "./irsa_proxy_role"
    count = var.proxy-role-count
    irsa-proxy-role-name = "${local.resource-prefix}-proxy-list-bucket-role-${count.index+1}"
    irsa-workload-role-name = "${local.resource-prefix}-list-bucket-role"
    eks-cluster-name = var.eks-cluster-name
}

module "irsa_proxy_role2" {
    source = "./irsa_proxy_role"
    count = var.proxy-role-count
    irsa-proxy-role-name = "${local.resource-prefix}-proxy-read-bucket-role-${count.index+1}"
    irsa-workload-role-name = "${local.resource-prefix}-read-bucket-role"
    eks-cluster-name = var.eks-cluster-name
}

module "irsa_proxy_role3" {
    source = "./irsa_proxy_role"
    count = var.proxy-role-count
    irsa-proxy-role-name = "${local.resource-prefix}-proxy-write-bucket-role-${count.index+1}"
    irsa-workload-role-name = "${local.resource-prefix}-write-bucket-role"
    eks-cluster-name = var.eks-cluster-name
}