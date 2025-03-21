module "elastio_asset_account" {
  source  = "terraform.cloudsmith.io/public/elastio-asset-account-stack-set/aws"
  version = "0.33.0"

  # For testing purposes
  # source = "../../"

  template_url = var.template_url

  permission_model = "SERVICE_MANAGED"
  deployment_targets = {
    account_filter_type     = "INTERSECTION"
    accounts                = var.accounts
    organizational_unit_ids = var.organizational_unit_ids
  }
  auto_deployment = {
    enabled = false
  }
}
