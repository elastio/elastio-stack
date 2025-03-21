# `elastio-nat-provision` module

Creates an AWS Cloudformation stack named `elastio-nat-provision-lambda` which deploys NAT gateways in the private subnets where Elastio scan job workers run. This is necessary only if you deploy Elastio into private subnets that don't have outbound Internet access already. Alternatively, you can deploy your own NAT gateway if you want to.

See the [`elastio-connector` module implementation](../../main.tf) for an example of how this module should be used.

## Installation

[Configure](../../README.md#configuring-the-terraform-modules-registry) the Elastio terraform module registry, and add this to your project:

```tf
module "elastio_nat_provision" {
  source  = "terraform.cloudsmith.io/public/elastio-nat-provision/aws"
  version = "0.33.0"

  // Provide input parameters
}
```
