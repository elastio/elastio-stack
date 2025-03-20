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

variable "admin_account_aws_profile" {
  type    = string
  default = null
}

variable "asset_account_aws_profile" {
  type    = string
  default = null
}
