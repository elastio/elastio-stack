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
module "elastio_policies" {
  # Use this module from the Cloudsmith registry via the URL in real code:
  # source = "terraform.cloudsmith.io/public/elastio-iam-policies/aws"
  source   = "../../../../../iam-policies/terraform"
  policies = ["ElastioAssetAccountDeployer"]
}

resource "aws_iam_role_policy_attachment" "execution_deployment" {
  provider = aws.asset

  policy_arn = module.elastio_policies.policies.ElastioAssetAccountDeployer.arn
  role       = aws_iam_role.execution.name
}
