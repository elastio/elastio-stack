# Elastio Asset Account CloudFormation Stack

See [this README](../..) for more details on what this stack does.

This is a Terraform module, that is a thin wrapper on top of an [`aws_cloudformation_stack`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack) resource used to deploy the Elastio Asset Account stack.

See the basic [usage example](./examples/basic/main.tf).

## Installation

[Configure](../../../README.md#configuring-the-terraform-modules-registry) the Elastio terraform module registry, and add this to your project:

```tf
module "elastio_asset_account" {
  source  = "terraform.cloudsmith.io/public/elastio-asset-account-cloudformation-stack/aws"
  version = "0.33.1"

  // Provide input parameters
}
```

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name                                                                     | Version |
| ------------------------------------------------------------------------ | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | ~> 1.9  |
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

| Name                                                                                                         | Description                                                                                                                                                                                                                                            | Type           | Default                 | Required |
| ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------- | ----------------------- | :------: |
| <a name="input_disable_rollback"></a> [disable_rollback](#input_disable_rollback)                            | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#disable_rollback-1)                                                                                                                   | `bool`         | `null`                  |    no    |
| <a name="input_encrypt_with_cmk"></a> [encrypt_with_cmk](#input_encrypt_with_cmk)                            | Provision an additional customer-managed KMS key to encrypt Lambda environment variables.<br/>This increases the cost of the stack.                                                                                                                    | `bool`         | `false`                 |    no    |
| <a name="input_iam_resource_names_prefix"></a> [iam_resource_names_prefix](#input_iam_resource_names_prefix) | Add a custom prefix to names of all IAM resources deployed by this stack.                                                                                                                                                                              | `string`       | `""`                    |    no    |
| <a name="input_iam_resource_names_suffix"></a> [iam_resource_names_suffix](#input_iam_resource_names_suffix) | Add a custom prefix to names of all IAM resources deployed by this stack.                                                                                                                                                                              | `string`       | `""`                    |    no    |
| <a name="input_iam_role_arn"></a> [iam_role_arn](#input_iam_role_arn)                                        | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#iam_role_arn-1)                                                                                                                       | `string`       | `null`                  |    no    |
| <a name="input_lambda_tracing"></a> [lambda_tracing](#input_lambda_tracing)                                  | Enable AWS X-Ray tracing for Lambda functions.<br/>This increases the cost of the stack.                                                                                                                                                               | `bool`         | `false`                 |    no    |
| <a name="input_notification_arns"></a> [notification_arns](#input_notification_arns)                         | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#notification_arns-1)                                                                                                                  | `list(string)` | `null`                  |    no    |
| <a name="input_on_failure"></a> [on_failure](#input_on_failure)                                              | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#on_failure-1)                                                                                                                         | `string`       | `null`                  |    no    |
| <a name="input_policy_body"></a> [policy_body](#input_policy_body)                                           | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#policy_body-1)                                                                                                                        | `string`       | `null`                  |    no    |
| <a name="input_policy_url"></a> [policy_url](#input_policy_url)                                              | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#policy_url-1)                                                                                                                         | `string`       | `null`                  |    no    |
| <a name="input_stack_name"></a> [stack_name](#input_stack_name)                                              | The name of the CloudFormation StackSet.                                                                                                                                                                                                               | `string`       | `"ElastioAssetAccount"` |    no    |
| <a name="input_tags"></a> [tags](#input_tags)                                                                | Additional tags to apply to all resources created by this stack.                                                                                                                                                                                       | `map(string)`  | `{}`                    |    no    |
| <a name="input_template_url"></a> [template_url](#input_template_url)                                        | The URL of the Elastio Asset Account CloudFormation template obtained from<br/>the Elastio Portal.<br/><br/>This parameter is sensitive, because anyone who knows this URL can deploy<br/>Elastio Account stack and linking it to your Elastio tenant. | `string`       | n/a                     |   yes    |
| <a name="input_timeout_in_minutes"></a> [timeout_in_minutes](#input_timeout_in_minutes)                      | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack#timeout_in_minutes-1)                                                                                                                 | `number`       | `null`                  |    no    |

## Outputs

| Name                                               | Description                                           |
| -------------------------------------------------- | ----------------------------------------------------- |
| <a name="output_stack"></a> [stack](#output_stack) | The outputs of the aws_cloudformation_stack resource. |

<!-- END_TF_DOCS -->
