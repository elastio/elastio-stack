module "elastio_asset_account" {
  source = "../../"

  providers = {
    aws = aws.admin
  }

  depends_on = [
    # Needs to wait for the execution role in the asset account to be fully created
    aws_iam_role_policy_attachment.execution_deployment,

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

  name = "AWSCloudFormationStackSetAdministrationRole"

  # Allow assuming for CFN with some `Condition` elements to prevent the confused deputy attack
  # as described in AWS docs: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-prereqs-self-managed.html#confused-deputy-mitigation
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "cloudformation.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ],
      "Condition" : {
        "StringEquals" : {
          "aws:SourceAccount" : local.admin_account_id
        },
        "StringLike" : {
          "aws:SourceArn" : "arn:aws:cloudformation:*:${local.admin_account_id}:stackset/*"
        }
      }
    }
  )
}

resource "aws_iam_role_policy" "admin_execution" {
  provider = aws.admin

  name = "AssumeExecutionRole"
  role = aws_iam_role.admin.name

  # Allow assuming the execution role in any (*) account to avoid coupling the
  # target accounts with assets with this policy.
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "sts:AssumeRole",
          "Resource" : "arn:aws:iam::*:role/AWSCloudFormationStackSetExecutionRole"
        }
      ]
    }
  )
}
