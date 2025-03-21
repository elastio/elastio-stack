locals {
  elastio_endpoint = "https://${var.elastio_tenant}/public-api/v1"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  connector_config = {
    region     = coalesce(var.region, data.aws_region.current.name),
    account_id = data.aws_caller_identity.current.account_id,
    vpc_id     = var.vpc_id
    subnet_ids = var.subnet_ids
  }
}

resource "terraform_data" "elastio_cloud_connector" {
  input = local.connector_config
  triggers_replace = {
    connector     = local.connector_config,
    account_stack = var.connector_account_stack.name,
  }

  provisioner "local-exec" {
    command = <<CMD
      curl "$elastio_endpoint/deploy-cloud-connector" \
        --location \
        --fail-with-body \
        --show-error \
        --retry-all-errors \
        --retry 5 \
        -X POST \
        -H "Authorization: Bearer $elastio_pat" \
        -H "Content-Type: application/json; charset=utf-8" \
        -d "$request_body"
    CMD

    environment = {
      elastio_endpoint = local.elastio_endpoint
      request_body     = jsonencode(self.input)

      # Using nonsensitive() to workaround the problem that the script's
      # output is entirely suppressed: https://github.com/hashicorp/terraform/issues/27154
      elastio_pat = nonsensitive(var.elastio_pat)
    }
  }
}
