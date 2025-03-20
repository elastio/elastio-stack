module "elastio_asset_accounts" {
  # Use the link from the real terraform registry here. Relative path is used for testing purposes.
  source = "../../"
  providers = {
    aws = aws.admin
  }

  # Needs to be deployed only after the execution role in the asset account is created
  depends_on = [aws_iam_role.execution]

  template_url = var.template_url

  # we are deploying just into a single asset account in this example
  accounts     = [local.asset_account_id]

  stack_set = {
    administration_role_arn = aws_iam_role.admin.arn
  }
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
