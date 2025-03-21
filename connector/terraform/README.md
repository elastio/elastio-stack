# Elastio Terraform Deployment

This is an example of how you may automate the deployment of the Elastio stack in your AWS account.

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

There is a terraform module under the `module` directory. It deploys all the necessary resources for Elastio to operate. It includes the following:

- AWS Cloudformation stack named `elastio-account-level-stack`, which is deployed once per AWS account and contains the required IAM resources
- Elastio Cloud Connector stack deployed by Elastio Portal via a REST API call. It contains Lambda functions, DynamoDB databases, S3 buckets, AWS Batch compute environments and other non-IAM resources.
- _Optional._ AWS Cloudformation stack named `elastio-nat-provision-lambda` which deploys NAT gateways in the private subnets where Elastio scan job workers run. This is necessary only if you deploy Elastio into private subnets that don't have outbound Internet access already. Alternatively, you can deploy your own NAT gateway if you want to.

Add this terraform module to your terraform project and specify the necessary input variables. Here you'll need to pass the PAT token you [generated earlier](#obtain-a-personal-access-token-pat), specify your Elastio tenant name and the list of regions with VPC/subnet configurations where you want to deploy Elastio.

> [!IMPORTANT]
> Make sure `curl` of version _at least_ `7.76.0` is installed on the machine that runs the terraform deployment (`terraform apply`). The provided terraform module uses a `local-exec` provisioner that uses `curl` to do a REST API call to Elastio Portal.

Here is an example usage of the module

```tf
provider "aws" {}
provider "http" {}

module "elastio" {
  source = "./module"
  elastio_pat = "{pat_token_from_elastio_portal}"
  elastio_tenant = "mycompany.app.elastio.com"
  elastio_cloud_connectors = [
    {
      region = "us-east-2"
      vpc_id = "vpc-0001"
      subnet_ids = [
        "subnet-0001",
        "subnet-0002"
      ]
    },
    {
      region = "us-east-1"
      vpc_id = "vpc-0002"
      subnet_ids = [
        "subnet-0003",
        "subnet-0004",
      ]
    }

    # Other optional configuration tweaks. See `module/variables.tf` for more info
    # iam_resource_names_prefix = "prefix"
  ]

  # This input is optional. Here you can specify the version of the NAT provisioning stack.
  # If you don't need it, just omit this input variable.
  elastio_nat_provision_stack = "v5"
}
```
