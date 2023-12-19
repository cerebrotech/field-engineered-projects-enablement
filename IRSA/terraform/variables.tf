
variable "eks-cluster-name" {
    type = string
}

variable "domino-irsa-namespace" {
    type = string
    default = "domino-field"
}

variable "resource-prefix" {
    type = string
    default = ""
}

variable "irsa-wl-role-suffix" {
    default = "irsa-workload"
}

variable "workload-policy-name" {
    default = ""
}

variable "proxy-role-count" {
    type = number
    default = 1
    description = "The number of proxy roles to associate with a given asset role"
}

locals {
    svc-role-name = length(var.resource-prefix) > 0 ? "${var.resource-prefix}-irsa-svc-role" : "${var.eks-cluster-name}-domino-irsa-svc-role"
    resource-prefix = length(var.resource-prefix) > 0 ? var.resource-prefix : "${var.eks-cluster-name}-domino"
    #wl-role-name = "${var.resource-prefix}-"
}