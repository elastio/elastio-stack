#########################
## Required parameters ##
#########################

variable "policies" {
  description = <<-DESCR
    A set of names of Elastio IAM policies to create. See the available policies
    in the README of the module.
  DESCR

  type     = set(string)
  nullable = false

  validation {
    condition     = length(var.policies) > 0
    error_message = "At least one policy must be specified."
  }

  validation {
    condition     = length(setsubtract(var.policies, local.available_policies)) == 0
    error_message = <<-ERR
      The following policy names are invalid:
      ${join(", ", setsubtract(var.policies, local.available_policies))}
    ERR
  }
}

locals {
  available_policies = [
    for policy in fileset("${path.module}/policies", "*.json") :
    substr(policy, 0, length(policy) - length(".json"))
  ]
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

variable "name_prefix" {
  description = "A prefix to apply to all resources created by this stack"

  type     = string
  nullable = false
  default  = ""
}

variable "name_suffix" {
  description = "A suffix to apply to all resources created by this stack"

  type     = string
  nullable = false
  default  = ""
}
