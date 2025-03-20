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
    List of AWS account IDs where the Elastio Asset Account stack instances will
    be deployed.

    You can specify `accounts` or `deployment_targets`, but not both.
  DESCR

  type    = list(string)
  default = null
}

variable "deployment_targets" {
  description = <<-DESCR
    More flexible way to specify the accounts where the Elastio Asset Account stack.
    This is passed directly as a parameter to the `aws_cloudformation_stack_instances`
    resource.

    You can specify `accounts` or `deployment_targets`, but not both.

    Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_instances#deployment_targets
  DESCR

  type    = any
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

variable "operation_preferences" {
  description = <<-DESCR
    Preferences for how AWS CloudFormation performs a stack set operation.

    Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_instances#operation_preferences
  DESCR

  type = object({
    concurrency_mode             = optional(string)
    failure_tolerance_count      = optional(number)
    failure_tolerance_percentage = optional(number)
    max_concurrent_count         = optional(number)
    max_concurrent_percentage    = optional(number)

    # Region settings are not supported, because there must be at most one stack per account in a single region.
  })
  default = null
}
variable "stack_set" {
  description = <<-DESCR
    Additional configurations override for the aws_cloudformation_stack_set resource.
    These parameters will be forwarded to the resource as-is. See the module's source
    code to see what parameters may be passed here.

    Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set
  DESCR

  type    = any
  default = {}
}

variable "stack_instances" {
  description = <<-DESCR
    Additional configurations override for the aws_cloudformation_stack_instances resource.
    These parameters will be forwarded to the resource as-is. See the module's source
    code to see what parameters may be passed here.

    Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_instances
  DESCR

  type    = any
  default = {}
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
