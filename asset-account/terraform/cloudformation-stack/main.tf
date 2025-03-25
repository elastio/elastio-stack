resource "aws_cloudformation_stack" "this" {
  tags = merge(var.tags, { "elastio:resource" = true })

  name         = var.stack_name
  template_url = var.template_url
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  disable_rollback   = var.disable_rollback
  notification_arns  = var.notification_arns
  on_failure         = var.on_failure
  policy_body        = var.policy_body
  policy_url         = var.policy_url
  iam_role_arn       = var.iam_role_arn
  timeout_in_minutes = var.timeout_in_minutes

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
