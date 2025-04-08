resource "aws_cloudformation_stack_set" "this" {
  tags = merge(var.tags, { "elastio:resource" = true })

  name                    = var.stack_set_name
  description             = var.stack_set_description
  administration_role_arn = var.administration_role_arn
  execution_role_name     = var.execution_role_name
  permission_model        = var.permission_model
  call_as                 = var.call_as
  template_url            = var.template_url

  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  dynamic "auto_deployment" {
    for_each = var.auto_deployment[*]
    content {
      enabled                          = auto_deployment.value.enabled
      retain_stacks_on_account_removal = auto_deployment.value.retain_stacks_on_account_removal
    }
  }

  dynamic "managed_execution" {
    for_each = var.managed_execution[*]
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

  # Temporarily disabled to prevent the users from the footgun of this bug
  # in Terraform AWS provider: https://github.com/hashicorp/terraform-provider-aws/issues/42172
  #
  # accounts = var.accounts

  regions = [var.stack_instances_region]

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

  retain_stacks = var.retain_stacks
}
