locals {
  connectors = {
    for connector in var.elastio_cloud_connectors :
    connector.region => connector
  }
}

module "account" {
  source = "./modules/account"

  elastio_pat    = var.elastio_pat
  elastio_tenant = var.elastio_tenant

  regional_configs                      = var.elastio_cloud_connectors
  encrypt_with_cmk                      = var.encrypt_with_cmk
  lambda_tracing                        = var.lambda_tracing
  global_managed_policies               = var.global_managed_policies
  global_permission_boundary            = var.global_permission_boundary
  iam_resource_names_prefix             = var.iam_resource_names_prefix
  iam_resource_names_suffix             = var.iam_resource_names_suffix
  iam_resource_names_static             = var.iam_resource_names_static
  disable_customer_managed_iam_policies = var.disable_customer_managed_iam_policies
  service_linked_roles                  = var.service_linked_roles
  ecr_public_prefix                     = var.ecr_public_prefix
  network_configuration                 = var.network_configuration
}

module "region" {
  source   = "./modules/region"
  for_each = local.connectors

  elastio_pat    = var.elastio_pat
  elastio_tenant = var.elastio_tenant

  region                  = each.value.region
  vpc_id                  = each.value.vpc_id
  subnet_ids              = each.value.subnet_ids
  connector_account_stack = module.account.cloudformation_stack
}

module "nat_provision" {
  source   = "./modules/nat-provision"
  for_each = var.elastio_nat_provision_stack == null ? {} : local.connectors

  template_version        = var.elastio_nat_provision_stack
  connector_account_stack = module.account.cloudformation_stack
}
