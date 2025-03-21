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

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name                                                                     | Version |
| ------------------------------------------------------------------------ | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | ~> 1.0  |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                   | ~> 5.0  |

## Providers

| Name                                             | Version |
| ------------------------------------------------ | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws) | ~> 5.0  |

## Modules

No modules.

## Resources

| Name                                                                                                                              | Type     |
| --------------------------------------------------------------------------------------------------------------------------------- | -------- |
| [aws_cloudformation_stack.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack) | resource |

## Inputs

| Name                                                                                                   | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Type                                                      | Default | Required |
| ------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- | ------- | :------: |
| <a name="input_connector_account_stack"></a> [connector_account_stack](#input_connector_account_stack) | The Elastio Connector Account stack metadata. This is used to inherit the<br/> configs by the `nat-provision` stack. The value for this parameter can be<br/> provided as the `cloudformation_stack` output of the `account` module, or<br/> you could use a `data "aws_cloudformation_stack"` data source to fetch the<br/> stack metadata and provide it here.                                                                                                                                                                                                                                                                                                                                                       | <pre>object({<br/> parameters = map(string)<br/> })</pre> | n/a     |   yes    |
| <a name="input_template_version"></a> [template_version](#input_template_version)                      | Specifies the version of Elastio NAT provision stack to deploy (e.g. `v5`).<br/><br/> This is a Cloudformation stack that automatically provisions NAT Gateways in<br/> your VPC when Elastio worker instances run to provide them with the outbound<br/> Internet access when Elastio is deployed in private subnets.<br/><br/> If you don't need this stack (e.g. you already have NAT gateways in your VPC<br/> or you deploy into public subnets) you can omit this parameter. The default<br/> value of `null` means there won't be any NAT provision stack deployed.<br/><br/> The source code of this stack can be found here:<br/> https://github.com/elastio/contrib/tree/master/elastio-nat-provision-lambda | `string`                                                  | `"v5"`  |    no    |

## Outputs

No outputs.

<!-- END_TF_DOCS -->
