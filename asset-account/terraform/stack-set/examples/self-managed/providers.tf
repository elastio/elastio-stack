provider "aws" {
  alias   = "admin"
  profile = var.admin_account_aws_profile
}

provider "aws" {
  alias   = "asset"
  profile = var.asset_account_aws_profile
}

data "aws_caller_identity" "admin" {
  provider = aws.admin
}

data "aws_caller_identity" "asset" {
  provider = aws.asset
}

locals {
  admin_account_id = data.aws_caller_identity.admin.account_id
  asset_account_id = data.aws_caller_identity.asset.account_id
}
