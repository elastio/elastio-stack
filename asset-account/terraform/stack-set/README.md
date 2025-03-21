# Elastio Asset Account CloudFormation StackSet

See [this README](../..) for more details on what this stack does.

This is a Terraform module, that is a thin wrapper on top of an [`aws_cloudformation_stack_set`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set) and [`aws_cloudformation_stack_instances`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_instances) resources used to deploy the Elastio Asset Account stack.

See the `examples` directory for some examples of how this module can be used:

- `self-managed` - deploy the stack set using the [self-managed permission model](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-getting-started-create-self-managed.html)
- `service-managed` - deploy the stack set using the [service-managed permission model](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-associate-stackset-with-org.html)

## Installation

[Configure](../../../README.md#configuring-the-terraform-modules-registry) the Elastio terraform module registry, and add this to your project:

```tf
module "elastio_asset_account" {
  source  = "terraform.cloudsmith.io/public/elastio-asset-account-stack-set/aws"
  version = "0.33.0"

  // Provide input parameters
}
```
