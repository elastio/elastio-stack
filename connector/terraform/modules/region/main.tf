locals {
  elastio_endpoint = "https://${var.elastio_tenant}/public-api/v1"
  headers = {
    Authorization = "Bearer ${var.elastio_pat}"
  }
}

resource "aws_cloudformation_stack" "elastio_nat_provision_stack" {
  count = var.elastio_nat_provision_stack == null ? 0 : 1

  name = "elastio-nat-provision-lambda"
  template_url = join(
    "/",
    [
      "https://elastio-prod-artifacts-us-east-2.s3.us-east-2.amazonaws.com",
      "contrib/elastio-nat-provision-lambda/${var.elastio_nat_provision_stack}",
      "cloudformation-lambda.yaml"
    ]
  )
  tags = {
    "elastio:resource" = "true"
  }
  capabilities = ["CAPABILITY_NAMED_IAM"]
  parameters = {
    for key, value in {
      EncryptWithCmk         = var.encrypt_with_cmk
      LambdaTracing          = var.lambda_tracing
      IamResourceNamesPrefix = var.iam_resource_names_prefix
      IamResourceNamesSuffix = var.iam_resource_names_suffix
      GlobalManagedPolicies = (
        var.global_managed_policies == null
        ? null
        : join(",", var.global_managed_policies)
      ),
      GlobalPermissionBoundary = var.global_permission_boundary,
    } :
    key => tostring(value)
    if value != null
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "terraform_data" "elastio_cloud_connector" {
  depends_on = [aws_cloudformation_stack.elastio_account_level_stack]

  input = each.value
  triggers_replace = {
    connector = {
      region     = coalesce(var.region, data.aws_region.current.name),
      account    = data.aws_caller_identity.current.account_id,
      vpc_id     = var.vpc_id
      subnet_ids = var.subnet_ids
    },
    account_stack = var.connector_account_stack_name,
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

      // Using nonsensitive() to workaround the problem that the script's
      // output is entirely suppressed: https://github.com/hashicorp/terraform/issues/27154
      elastio_pat = nonsensitive(var.elastio_pat)
    }
  }
}
