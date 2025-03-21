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

variable "version" {
  description = <<DESCR
    Specifies the version of Elastio NAT provision stack to deploy (e.g. `v5`).

    This is a Cloudformation stack that automatically provisions NAT Gateways in
    your VPC when Elastio worker instances run to provide them with the outbound
    Internet access when Elastio is deployed in private subnets.

    If you don't need this stack (e.g. you already have NAT gateways in your VPC
    or you deploy into public subnets) you can omit this parameter. The default
    value of `null` means there won't be any NAT provision stack deployed.

    The source code of this stack can be found here:
    https://github.com/elastio/contrib/tree/master/elastio-nat-provision-lambda
  DESCR

  type     = string
  nullable = true
  default  = "v5"
}
