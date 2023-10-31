
data "aws_iam_policy_document" "workload-role-trust-policy" {
    statement {
      actions = ["sts:AssumeRole"]
      effect = "Allow"
      principals {
        type = "AWS"
        identifiers = var.associated-proxy-role-list
      }
    }
}

resource "aws_iam_role" "irsa-workload-role" {
    name = var.irsa-workload-role-name
    assume_role_policy = data.aws_iam_policy_document.workload-role-trust-policy.json
}

resource "aws_iam_policy" "irsa-workload-policy" {
    count = length(var.irsa-workload-policy) > 0 ? 1 : 0
    name = "${var.irsa-workload-role-name}-policy"
    policy = var.irsa-workload-policy
}

resource "aws_iam_role_policy_attachment" "irsa-workload-role-policy" {
    count = length(var.irsa-workload-policy) > 0 ? 1 : 0
    role = aws_iam_role.irsa-workload-role.name
    policy_arn = aws_iam_policy.irsa-workload-policy[0].arn
}