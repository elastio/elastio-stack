# `elastio-connector-region` module

Deploys the Elastio Cloud Connector stack via a REST API call to the Elastio Portal. The final stack contains Lambda functions, DynamoDB databases, S3 buckets, AWS Batch compute environments and other non-IAM resources.

See the [`elastio-connector` module implementation](../../main.tf) for an example of how this module should be used.

## Installation

[Configure](../../README.md#configuring-the-terraform-modules-registry) the Elastio terraform module registry, and add this to your project:

```tf
module "elastio_connector_region" {
  source  = "terraform.cloudsmith.io/public/elastio-connector-region/aws"
  version = "0.33.0"

  // Provide input parameters
}
```
