#########################
## Required parameters ##
#########################

variable "connector_account_stack" {
  description = <<DESCR
    The Elastio Connector Account stack metadata. This is used to inherit the
    configs by the `nat-provision` stack. The value for this parameter can be
    provided as the `cloudformation_stack` output of the `account` module, or
    you could use a `data "aws_cloudformation_stack"` data source to fetch the
    stack metadata and provide it here.
  DESCR

  type = object({
    parameters = map(string)
  })

  nullable = false
}

#########################
## Optional parameters ##
#########################

variable "template_version" {
  description = <<DESCR
    Specifies the version of Elastio NAT provision stack to deploy (e.g. `v5`).
  DESCR

  type     = string
  nullable = false
  default  = "v5"
}
