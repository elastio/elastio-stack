# `elastio-iam-policies` module

This Terraform module deploys additional Elastio IAM managed policies that you can use for managing Elastio stacks.

## Installation

[Configure](../../README.md#configuring-the-terraform-modules-registry) the Elastio terraform module registry, and add this to your project:

```tf
module "elastio_policies" {
  source  = "terraform.cloudsmith.io/public/elastio-iam-policies/aws"
  version = "0.33.0"

  // Provide input parameters
}
```

## Usage

Specify the set of names of policies from the list of [available policies](#available-policies) that you want to deploy as a `policies` input to the module.

The policies are generated using TypeScript. Their final JSON output is stored as `policies/{PolicyName}.json` documents in this module's directory. You can see the original policy source code with comments about the reasoning for some IAM permissions if you click on the policy names in the table below.

See the basic [usage example](./examples/basic/main.tf).

## Available Policies

<!-- ELASTIO_BEGIN_POLICY_NAMES -->

| Policy                                                       | Description                                                    |
| ------------------------------------------------------------ | -------------------------------------------------------------- |
| [`ElastioAssetAccountDeployer`][ElastioAssetAccountDeployer] | Permissions required to deploy the Elastio Asset Account stack |
| [`ElastioAwsBackupEc2Scan`][ElastioAwsBackupEc2Scan]         | Allows Elastio to scan AWS Backup EC2 recovery points.         |

[ElastioAssetAccountDeployer]: ../../codegen/src/policies/ElastioAssetAccountDeployer.ts
[ElastioAwsBackupEc2Scan]: ../../codegen/src/policies/ElastioAwsBackupEc2Scan.ts

<!-- ELASTIO_END_POLICY_NAMES -->

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

| Name                                                                                                          | Type     |
| ------------------------------------------------------------------------------------------------------------- | -------- |
| [aws_iam_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |

## Inputs

| Name                                                               | Description                                                                                                   | Type          | Default | Required |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- | ------------- | ------- | :------: |
| <a name="input_name_prefix"></a> [name_prefix](#input_name_prefix) | A prefix to apply to all resources created by this stack                                                      | `string`      | `""`    |    no    |
| <a name="input_name_suffix"></a> [name_suffix](#input_name_suffix) | A suffix to apply to all resources created by this stack                                                      | `string`      | `""`    |    no    |
| <a name="input_policies"></a> [policies](#input_policies)          | A set of names of Elastio IAM policies to create. See the available policies<br/>in the README of the module. | `set(string)` | n/a     |   yes    |
| <a name="input_tags"></a> [tags](#input_tags)                      | Additional tags to apply to all resources created by this stack.                                              | `map(string)` | `{}`    |    no    |

## Outputs

| Name                                                        | Description                                                    |
| ----------------------------------------------------------- | -------------------------------------------------------------- |
| <a name="output_policies"></a> [policies](#output_policies) | A map of the created Elastio IAM policies keyed by their names |

<!-- END_TF_DOCS -->
