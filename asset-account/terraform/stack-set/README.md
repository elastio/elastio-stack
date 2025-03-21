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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudformation_stack_instances.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_instances) | resource |
| [aws_cloudformation_stack_set.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_accounts"></a> [accounts](#input\_accounts) | The IDs AWS accounts where you want to create stack instances.<br/><br/>Specify `accounts` only if you are using `SELF_MANAGED` permissions model.<br/>If you are using the `SERVICE_MANAGED` permissions model specify `deployment_targets` instead. | `list(string)` | `null` | no |
| <a name="input_administration_role_arn"></a> [administration\_role\_arn](#input\_administration\_role\_arn) | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set#administration_role_arn-1) | `string` | `null` | no |
| <a name="input_auto_deployment"></a> [auto\_deployment](#input\_auto\_deployment) | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set#auto_deployment-1) | <pre>object({<br/>    enabled                          = optional(bool)<br/>    retain_stacks_on_account_removal = optional(bool)<br/>  })</pre> | `null` | no |
| <a name="input_call_as"></a> [call\_as](#input\_call\_as) | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set#call_as-1) | `string` | `null` | no |
| <a name="input_deployment_targets"></a> [deployment\_targets](#input\_deployment\_targets) | The AWS Organizations accounts for which to create stack instances.<br/><br/>Specify `deployment_targets` only if you are using `SERVICE_MANAGED` permissions model.<br/>If you are using the `SELF_MANAGED` permissions model specify `accounts` instead.<br/><br/>[Details](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_instances#deployment_targets) | <pre>object({<br/>    account_filter_type     = optional(string)<br/>    accounts                = optional(list(string))<br/>    accounts_url            = optional(string)<br/>    organizational_unit_ids = optional(list(string))<br/>  })</pre> | `null` | no |
| <a name="input_encrypt_with_cmk"></a> [encrypt\_with\_cmk](#input\_encrypt\_with\_cmk) | Provision an additional customer-managed KMS key to encrypt Lambda environment variables.<br/>This increases the cost of the stack. | `bool` | `false` | no |
| <a name="input_execution_role_name"></a> [execution\_role\_name](#input\_execution\_role\_name) | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set#execution_role_name-1) | `string` | `null` | no |
| <a name="input_iam_resource_names_prefix"></a> [iam\_resource\_names\_prefix](#input\_iam\_resource\_names\_prefix) | Add a custom prefix to names of all IAM resources deployed by this stack. | `string` | `""` | no |
| <a name="input_iam_resource_names_suffix"></a> [iam\_resource\_names\_suffix](#input\_iam\_resource\_names\_suffix) | Add a custom prefix to names of all IAM resources deployed by this stack. | `string` | `""` | no |
| <a name="input_lambda_tracing"></a> [lambda\_tracing](#input\_lambda\_tracing) | Enable AWS X-Ray tracing for Lambda functions.<br/>This increases the cost of the stack. | `bool` | `false` | no |
| <a name="input_managed_execution"></a> [managed\_execution](#input\_managed\_execution) | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set#managed_execution-1) | <pre>object({<br/>    active = optional(bool)<br/>  })</pre> | `null` | no |
| <a name="input_operation_preferences"></a> [operation\_preferences](#input\_operation\_preferences) | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_instances#operation_preferences) | <pre>object({<br/>    concurrency_mode             = optional(string)<br/>    failure_tolerance_count      = optional(number)<br/>    failure_tolerance_percentage = optional(number)<br/>    max_concurrent_count         = optional(number)<br/>    max_concurrent_percentage    = optional(number)<br/><br/>    # Region settings are not supported, because there must be at most one stack per account in a single region.<br/>  })</pre> | `null` | no |
| <a name="input_permission_model"></a> [permission\_model](#input\_permission\_model) | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set#permission_model-1) | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | The AWS region where the Elastio Asset Account stack instances will be deployed.<br/>It is just a single region because this stack is deployed only once per AWS account. | `string` | `"us-east-1"` | no |
| <a name="input_retain_stacks"></a> [retain\_stacks](#input\_retain\_stacks) | [See docs here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_instances#retain_stacks-1) | `bool` | `null` | no |
| <a name="input_stack_set_description"></a> [stack\_set\_description](#input\_stack\_set\_description) | n/a | `string` | `"Elastio Asset Account StackSet creates IAM roles to link the AWS accounts with\nthe Elastio Connector. This allows the Elastio Connector to scan the assets\navailable in the account where the Elastio Asset Account stack instances are\ndeployed.\n"` | no |
| <a name="input_stack_set_name"></a> [stack\_set\_name](#input\_stack\_set\_name) | n/a | `string` | `"ElastioAssetAccount"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources created by this stack. | `map(string)` | `{}` | no |
| <a name="input_template_url"></a> [template\_url](#input\_template\_url) | The URL of the Elastio Asset Account CloudFormation template obtained from<br/>the Elastio Portal.<br/><br/>This parameter is sensitive, because anyone who knows this URL can deploy<br/>Elastio Account stack and linking it to your Elastio tenant. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_stack_instances"></a> [stack\_instances](#output\_stack\_instances) | The outputs of the aws\_cloudformation\_stack\_instances resource. |
| <a name="output_stack_set"></a> [stack\_set](#output\_stack\_set) | The outputs of the aws\_cloudformation\_stack\_set resource. |
<!-- END_TF_DOCS -->