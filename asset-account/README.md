# Elastio Asset Account Stack

Elastio Asset Account stack creates IAM roles to link the AWS account with the Elastio Connector. This allows the Elastio Connector to scan the assets available in the account where the Elastio Asset Account stack is deployed.

There are several ways to deploy the Elastio Asset Account stack, that we'll review below.

## AWS CloudFormation StackSet

You can generate the CloudFormation template link for your Elastio Asset Account using the Elastio Portal UI and then deploy it via a CloudFormation StackSet either manually, or using the Elastio official Terraform wrapper module for this.

See the [`terraform/stack-set`](./terraform/stack-set) to get started.
