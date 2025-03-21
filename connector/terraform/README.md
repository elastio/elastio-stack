# Elastio Connector Terraform Deployment

This directory contains terraform modules that you may use to automate the deployment of the Elastio Connector stacks in your AWS accounts.

## Obtain a Personal Access Token (PAT)

First of all, you'll need a secret PAT token to authenticate your Elastio installation with the Elastio Portal. You can generate one by following the steps below.

1. Open the [Elastio Portal](https://login.elastio.com/) in your web browser.
2. Go to the `Settings` page.
3. Open the `API access` tab.
4. Click on `Add New Access Token`.
5. Enter the name for the token, for example `Elastio deployment`.
6. Select the scope `Sources: Write` for the token.
7. Click on `Generate Token`.
8. Copy the generated token.
9. _Optional step._ Save the token in a secure place like 1Password or any other secret management system of your choice. This way you won't lose it.

## Add Elastio to Your Terraform

There is are several terraform modules that you can use. We'll review all of them below.

## Installation

[Configure](../../README.md#configuring-the-terraform-modules-registry) the Elastio terraform module registry before adding any Elastio terraform modules to your project.

### `elastio-connector` module

This module provides the easiest way to get started. It resides as the top-level module in this directory. It deploys all the necessary resources for Elastio to operate in a single module for the entire AWS account and covers many regions.

Add this terraform module to your terraform project and specify the necessary input variables. Here you'll need to pass the PAT token you [generated earlier](#obtain-a-personal-access-token-pat).

> [!IMPORTANT]
> Make sure `curl` of version _at least_ `7.76.0` is installed on the machine that runs the terraform deployment (`terraform apply`). The provided terraform module uses a `local-exec` provisioner that uses `curl` to do a REST API call to Elastio Portal.

Here is the basic example usage of the module that deploys Elastio Connectors in several regions allowing you to scan your assets in these regions.

```tf
module "elastio_connectors" {
  source  = "terraform.cloudsmith.io/public/elastio-connector/aws"
  version = "0.33.0"

  elastio_tenant = var.elastio_tenant
  elastio_pat    = var.elastio_pat

  elastio_cloud_connectors = [
    {
      region = "us-east-1"
    },
    {
      region = "us-east-2",
    }
  ]
}
```

You can find the full version of this example in [`examples/basic`](./examples/basic).

This module deploys the following three modules internally, that you can deploy individually if a finer grained control over the deployment is required. You may use them, for example, if you need to deploy regional stacks in separate terraform projects instead of using a single one that deploys all regions.

### `elastio-connector-account` module

Creates an AWS Cloudformation stack named `elastio-account-level-stack`, which is deployed once per AWS account and contains the required IAM resources (roles, policies, etc.) for Elastio Connector to operate in the same account.

See [`modules/account`](./modules/account) directory for details.

### `elastio-connector-region` module

Deploys the Elastio Cloud Connector stack via a REST API call to the Elastio Portal. The final stack contains Lambda functions, DynamoDB databases, S3 buckets, AWS Batch compute environments and other non-IAM resources.

See [`modules/region`](./modules/region) directory for details.

### `elastio-nat-provision` module

_Optional._ AWS Cloudformation stack named `elastio-nat-provision-lambda` which deploys NAT gateways in the private subnets where Elastio scan job workers run. This is necessary only if you deploy Elastio into private subnets that don't have outbound Internet access already. Alternatively, you can deploy your own NAT gateway if you want to.

See [`modules/nat-provision`](./modules/nat-provision) directory for details.
