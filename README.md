# Elastio Stack

This repository contains necessary IaC code to deploy the resources of elastio scanning solution in your cloud account.

## Configure the Elastio Terraform Modules Registry

Elastio terraform modules are published to the public Cloudsmith registry. In order to use them from that registry add this to your [`.terraformrc`](https://developer.hashicorp.com/terraform/cli/config/config-file), which should reside in your home directory (if you are on Linux):


```hcl
credentials "terraform.cloudsmith.io" {
  token = "elastio/public/"
}
```
