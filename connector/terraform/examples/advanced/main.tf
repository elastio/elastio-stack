module "elastio_connectors" {
  source = "../../"

  elastio_tenant = var.elastio_tenant
  elastio_pat    = var.elastio_pat

  elastio_cloud_connectors = [
    {
      region = "us-east-1"
    },
    {
      region = "us-east-2",
    }
  ]

  global_managed_policies = var.global_managed_policies
}
