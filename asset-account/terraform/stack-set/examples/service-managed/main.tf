module "elastio_asset_account" {
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
