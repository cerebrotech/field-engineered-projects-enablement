

module "irsa_workload_role1" {
    source = "./irsa_workload_role"
    associated-proxy-role-list = module.irsa_proxy_role1[*].proxy-role-arn
    irsa-workload-role-name = "${local.resource-prefix}-list-bucket-role"
    irsa-workload-policy = data.aws_iam_policy_document.irsa-workload-example-policy.json
}

module "irsa_workload_role2" {
    source = "./irsa_workload_role"
    associated-proxy-role-list = module.irsa_proxy_role2[*].proxy-role-arn
    irsa-workload-role-name = "${local.resource-prefix}-read-bucket-role"
    irsa-workload-policy = data.aws_iam_policy_document.irsa-workload-example-policy.json
}


module "irsa_workload_role3" {
    source = "./irsa_workload_role"
    associated-proxy-role-list = module.irsa_proxy_role2[*].proxy-role-arn
    irsa-workload-role-name = "${local.resource-prefix}-write-bucket-role"
    # The below is commented to show what would happen when a policy document isn't passed in.
    # The policy for this role won't get created, so it will need to be created and attached to the role manually.
    # irsa-workload-policy = data.aws_iam_policy_document.irsa-workload-example-policy.json
}
