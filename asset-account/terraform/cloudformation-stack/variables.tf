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

#########################
## Optional parameters ##
#########################

variable "tags" {
  description = <<-DESCR
    Additional tags to apply to all resources created by this stack.
  DESCR

  type    = map(string)
  default = {}
}

variable "stack_name" {
  description = "The name of the CloudFormation StackSet."
  type        = string
  nullable    = false
  default     = "ElastioAssetAccount"
}

variable "disable_rollback" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#disable_rollback-1)"

  type    = bool
  default = null
}

variable "notification_arns" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#notification_arns-1)"

  type    = list(string)
  default = null
}

variable "on_failure" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#on_failure-1)"

  type    = string
  default = null
}

variable "policy_body" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#policy_body-1)"

  type    = string
  default = null
}

variable "policy_url" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#policy_url-1)"

  type    = string
  default = null
}

variable "iam_role_arn" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#iam_role_arn-1)"

  type    = string
  default = null
}

variable "timeout_in_minutes" {
  description = "[See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#timeout_in_minutes-1)"

  type    = number
  default = null
}
