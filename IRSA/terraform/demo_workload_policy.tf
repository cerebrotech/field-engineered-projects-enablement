
# These policies are included for demo purposes only. Please comment/remove the below code in a real env.

data "aws_iam_policy_document" "irsa-workload-example-policy" {
    provider = aws.asset-acct
    statement {
      actions = ["s3:ListBucket"]
      effect = "Allow"
      resources = ["*"]
    }
}

# resource "aws_iam_role_policy_attachment" "irsa-workload-example" {
#     provider = aws.asset-acct
#     role = module.irsa_workload_role3.name
#     policy_arn = aws_iam_policy.irsa-workload-example-policy.arn
# }

#resource "aws_iam_policy" "irsa-workload-example-policy" {
#    provider = aws.asset-acct
#    name = "${local.wl-role-name}-policy"
#    policy = data.aws_iam_policy_document.irsa-workload-example-policy.json
#}