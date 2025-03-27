module "elastio_asset_account" {
  source = "../../"

  stack_name = "ElastioAssetAccount2"

  template_url     = var.template_url
  encrypt_with_cmk = true
  iam_role_arn     = time_sleep.iam.triggers.deployer_role_arn
}

resource "aws_iam_role" "deployer" {
  name = "ElastioAssetAccountDeployer"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow"
          "Principal" : {
            "Service" : "cloudformation.amazonaws.com"
          }
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "elastio_asset_account_deployer" {
  role       = aws_iam_role.deployer.name
  policy_arn = module.elastio_policies.policies.ElastioAssetAccountDeployer.arn
}

module "elastio_policies" {
  source   = "../../../../../iam-policies/terraform"
  policies = ["ElastioAssetAccountDeployer"]
}

# Wait for the IAM role and policies to propagate
resource "time_sleep" "iam" {
  create_duration = "20s"

  depends_on = [aws_iam_role_policy_attachment.elastio_asset_account_deployer]

  triggers = {
    deployer_role_arn = aws_iam_role.deployer.arn
  }
}
