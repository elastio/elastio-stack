module "elastio_asset_accounts" {
  # Use the link from the real terraform registry here. Relative path is used for testing purposes.
  source = "../../"

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
