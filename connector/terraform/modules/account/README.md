# `elastio-connector-account` module

Deploys an AWS Cloudformation stack named `elastio-account-level-stack`, which is deployed once per AWS account and contains the required IAM resources (roles, policies, etc.) for Elastio Connector to operate in the same account.

See the [`elastio-connector` module implementation](../../main.tf) for an example of how this module should be used.

## Installation

[Configure](../../README.md#configuring-the-terraform-modules-registry) the Elastio terraform module registry, and add this to your project:

```tf
module "elastio_connector_account" {
  source  = "terraform.cloudsmith.io/public/elastio-conenctor-account/aws"
  version = "0.33.0"

  // Provide input parameters
}
```
