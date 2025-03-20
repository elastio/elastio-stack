
resource "aws_cloudformation_stack_set" "this" {
  name = lookup(var.stack_set, "name", "ElastioAssetAccount")
  description = lookup(var.stack_set, "description",
    <<-DESCR
      Elastio Asset Account StackSet creates IAM roles to link the AWS accounts with
      the Elastio Connector. This allows the Elastio Connector to scan the assets
      available in the account where the Elastio Asset Account stack instances are
      deployed.
    DESCR
  )

  administration_role_arn = lookup(var.stack_set, "administration_role_arn", null)

  dynamic "auto_deployment" {
    for_each = lookup(var.stack_set, "auto_deployment", [])
    content {
      enabled                          = auto_deployment.value.enabled
      retain_stacks_on_account_removal = auto_deployment.value.retain_stacks_on_account_removal
    }
  }

  capabilities        = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]
  execution_role_name = lookup(var.stack_set, "execution_role_name", null)

  dynamic "managed_execution" {
    for_each = lookup(var.stack_set, "managed_execution", [])
    content {
      active = managed_execution.value.active
    }
  }

  dynamic "operation_preferences" {
    for_each = var.operation_preferences[*]
    content {
      failure_tolerance_count      = operation_preferences.value.failure_tolerance_count
      failure_tolerance_percentage = operation_preferences.value.failure_tolerance_percentage
      max_concurrent_count         = operation_preferences.value.max_concurrent_count
      max_concurrent_percentage    = operation_preferences.value.max_concurrent_percentage
    }
  }

  parameters = {
    for key, value in {
      iamResourceNamesPrefix = var.iam_resource_names_prefix
      iamResourceNamesSuffix = var.iam_resource_names_suffix
      encryptWithCmk         = var.encrypt_with_cmk
      lambdaTracing          = var.lambda_tracing
    } :
    key => tostring(value)
  }

  permission_model = lookup(var.stack_set, "permission_model", null)
  call_as          = lookup(var.stack_set, "call_as", null)
  tags = merge(
    var.tags,
    lookup(var.stack_set, "tags", {}),
    {
      "elastio:resource" = true
    },
  )

  template_url = var.template_url

  # Ignore some internal parameter values
  lifecycle {
    ignore_changes = [
      parameters["cloudConnectorAccountId"],
      parameters["cloudConnectorRoleExternalId"],
      parameters["deploymentNotificationToken"],
      parameters["deploymentNotificationTopicArn"],
    ]
  }
}

resource "aws_cloudformation_stack_instances" "this" {
  stack_set_name = aws_cloudformation_stack_set.this.name

  accounts = var.accounts

  dynamic "deployment_targets" {
    for_each = var.deployment_targets[*]
    content {
      account_filter_type     = deployment_targets.value.account_filter_type
      accounts                = deployment_targets.value.accounts
      accounts_url            = deployment_targets.value.accounts_url
      organizational_unit_ids = deployment_targets.value.organizational_unit_ids
    }
  }

  dynamic "operation_preferences" {
    for_each = var.operation_preferences[*]
    content {
      concurrency_mode = operation_preferences.concurrency_mode
    }
  }

  retain_stacks = lookup(var.stack_instances, "retain_stacks", null)
}
