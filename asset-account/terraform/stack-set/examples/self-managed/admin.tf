module "elastio_asset_account" {
  source  = "terraform.cloudsmith.io/public/elastio-asset-account-stack-set/aws"
  version = "0.33.0"

  # For testing purposes
  # source = "../../"

  providers = {
    aws = aws.admin
  }

  depends_on = [
    # Needs to wait for the execution role in the asset account to be fully created
    aws_iam_role_policy.execution_deployment,

    # Needs to wait for the admin role in the admin account to be fully created
    aws_iam_role_policy.admin_execution,
  ]

  template_url = var.template_url

  # We are deploying just into a single asset account in this example
  accounts = [local.asset_account_id]

  administration_role_arn = aws_iam_role.admin.arn
}

# Admin role, that StackSets will use to access the asset accounts to deploy the stacks
resource "aws_iam_role" "admin" {
  provider = aws.admin

  assume_role_policy = data.aws_iam_policy_document.admin_trust.json
  name               = "AWSCloudFormationStackSetAdministrationRole"
}

data "aws_iam_policy_document" "admin_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["cloudformation.amazonaws.com"]
      type        = "Service"
    }

    # Conditions to prevent the confused deputy attack
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.admin_account_id]
    }

    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudformation:*:${local.admin_account_id}:stackset/*"]
    }
  }
}

data "aws_iam_policy_document" "admin_execution" {
  statement {
    actions   = ["sts:AssumeRole"]
    effect    = "Allow"
    resources = ["arn:aws:iam::*:role/AWSCloudFormationStackSetExecutionRole"]
  }
}

resource "aws_iam_role_policy" "admin_execution" {
  provider = aws.admin

  name   = "AssumeExecutionRole"
  policy = data.aws_iam_policy_document.admin_execution.json
  role   = aws_iam_role.admin.name
}
