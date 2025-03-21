#########################
## Required parameters ##
#########################

variable "template_url" {
  description = <<-DESCR
    The URL of the Elastio Asset Account CloudFormation template obtained from
    the Elastio Portal.

    This parameter is sensitive, because anyone who knows this URL can deploy
    Elastio Account stack and linking it to your Elastio tenant.
  DESCR

  sensitive = true
  type      = string
  nullable  = false
}

variable "accounts" {
  description = <<-DESCR
    The IDs AWS accounts where you want to create stack instances.

    Specify `accounts` only if you are using `SELF_MANAGED` permissions model.
    If you are using the `SERVICE_MANAGED` permissions model specify `deployment_targets` instead.
  DESCR

  type    = list(string)
  default = null
}

variable "deployment_targets" {
  description = <<-DESCR
    The AWS Organizations accounts for which to create stack instances.

    Specify `deployment_targets` only if you are using `SERVICE_MANAGED` permissions model.
    If you are using the `SELF_MANAGED` permissions model specify `accounts` instead.

    [Details](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_instances#deployment_targets)
  DESCR

  type = object({
    account_filter_type     = optional(string)
    accounts                = optional(list(string))
    accounts_url            = optional(string)
    organizational_unit_ids = optional(list(string))
  })
  default = null
}

#########################
## Optional parameters ##
#########################

variable "region" {
  description = <<-DESCR
    The AWS region where the Elastio Asset Account stack instances will be deployed.
    It is just a single region because this stack is deployed only once per AWS account.
  DESCR

  type    = string
  default = "us-east-1"
}

variable "tags" {
  description = <<-DESCR
    Additional tags to apply to all resources created by this stack.
  DESCR

  type    = map(string)
  default = {}
}

variable "auto_deployment" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set#auto_deployment-1)"

  type = object({
    enabled                          = optional(bool)
    retain_stacks_on_account_removal = optional(bool)
  })

  default = null
}

variable "stack_set_name" {
  type     = string
  nullable = false
  default  = "ElastioAssetAccount"
}

variable "stack_set_description" {
  type     = string
  nullable = false
  default  = <<-DESCR
    Elastio Asset Account StackSet creates IAM roles to link the AWS accounts with
    the Elastio Connector. This allows the Elastio Connector to scan the assets
    available in the account where the Elastio Asset Account stack instances are
    deployed.
  DESCR
}

##################################
## Deployment execution options ##
##################################

variable "operation_preferences" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_instances#operation_preferences)"

  type = object({
    concurrency_mode             = optional(string)
    failure_tolerance_count      = optional(number)
    failure_tolerance_percentage = optional(number)
    max_concurrent_count         = optional(number)
    max_concurrent_percentage    = optional(number)

    # Region settings are not supported, because
    # there must be at most one stack per account
    # in a single region.
  })
  default = null
}

variable "managed_execution" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set#managed_execution-1)"

  type = object({
    active = optional(bool)
  })
  default = null
}

variable "administration_role_arn" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set#administration_role_arn-1)"

  type    = string
  default = null
}

variable "execution_role_name" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set#execution_role_name-1)"

  type    = string
  default = null
}

variable "permission_model" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set#permission_model-1)"

  type    = string
  default = null
}

variable "call_as" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set#call_as-1)"

  type    = string
  default = null
}

variable "retain_stacks" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_instances#retain_stacks-1)"

  type    = bool
  default = null
}

######################################################
## Optional parameters of the Cloudformation stacks ##
######################################################

variable "iam_resource_names_prefix" {
  description = <<-DESCR
    Add a custom prefix to names of all IAM resources deployed by this stack.
  DESCR

  type     = string
  nullable = false
  default  = ""
}

variable "iam_resource_names_suffix" {
  description = <<-DESCR
    Add a custom prefix to names of all IAM resources deployed by this stack.
  DESCR

  type     = string
  nullable = false
  default  = ""
}

variable "encrypt_with_cmk" {
  description = <<-DESCR
    Provision an additional customer-managed KMS key to encrypt Lambda environment variables.
    This increases the cost of the stack.
  DESCR

  type     = bool
  nullable = false
  default  = false
}

variable "lambda_tracing" {
  description = <<-DESCR
    Enable AWS X-Ray tracing for Lambda functions.
    This increases the cost of the stack.
  DESCR

  type     = bool
  nullable = false
  default  = false
}
