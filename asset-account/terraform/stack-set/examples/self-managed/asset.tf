resource "aws_iam_role" "execution" {
  provider = aws.asset

  name               = "AWSCloudFormationStackSetExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.execution_trust.json
}

data "aws_iam_policy_document" "execution_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = [aws_iam_role.admin.arn]
      type        = "AWS"
    }
  }
}

# Specifies the set of permissions required for the deployment of the Cloudfomation stack
data "aws_iam_policy_document" "execution_deployment" {
  statement {
    actions   = ["*"]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "execution_deployment" {
  provider = aws.asset

  name   = "Deployment"
  policy = data.aws_iam_policy_document.execution_deployment.json
  role   = aws_iam_role.execution.name
}
