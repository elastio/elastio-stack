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
  type = list(string)

  description = <<-DESCR
    List of AWS account IDs where the Elastio Asset Account stack instances will
    be deployed.
  DESCR
}

variable "organizational_unit_ids" {
  type = list(string)

  description = <<-DESCR
    Organization root ID or organizational unit (OU) IDs to which stack sets deploy.
  DESCR
}
