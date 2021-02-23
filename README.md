[terraform-download]: https://www.terraform.io/downloads.html
[red-stack-tar]: http://repo.assur.io/release/reds.tar.gz
[aws-cli-installation]: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html

# elastio

This repository contains necessary code to deploy the resources of elastio backup solution in your cloud account (currently only AWS is supported).
We will refer to the deployed resources as **Red Stack** further.
Please follow either [automated](#automated-deployment-bash) or [manual](#manual-deployment) deployment instructions described bellow.

## Automated deployment (bash)

> Automated deployment is not supported for Windows, if you do want to do it on Windows, please follow [manual deployment](#manual-deployment) steps.

The script `reds-deploy.sh` automatically downloads the released artifacts and
deploys the Red Stack to your account.

Be sure to have [`aws` cli version `2`][aws-cli-installation] installed and
configured with the default profile before running this script.

Run the deployment script with your own parameters inserted for `--stack-name`,
optional `--out-dir`, etc.

```bash
curl -o ./reds-deploy.sh https://raw.githubusercontent.com/elastio/elastio-stack/master/scripts/reds-deploy.sh
bash -i ./reds-deploy.sh --stack-name <your_company_name_or_username> --out-dir ./elastio-stack
```

`--out-dir` parameter here is optional, but recommended. It allows for saving the initialized
terraform project used to deploy the stack to the specified directory on your filesystem.

You can also override the destination AWS region by specifying `--aws-region` argument.

For more information run the script with `--help` argument.

## Manual deployment

Our deployment heavily depends on `terraform` version `0.14`, so please make sure
to install it from [here][terraform-download] before proceeding.
We assume it is available via `$PATH` environment variable as `terraform` command.

We also assume you have [`aws` cli version `2`][aws-cli-installation] installed
and configured with the default profile.

Download the artifacts tarball from [here][red-stack-tar] and untar it to some place
convenient for you.

Before proceeding with the following instructions we recommend setting the following
environment variables to avoid specifying `terraform` inputs repeatedly:

```bash
# Some identifier that will be used in deployed resources' names to avoid name conflicts
# This must contain only alphanumeric characters and dashes
export TF_VAR_stack_name='my-company-name'

# Use the default aws region configured for your current aws account or replace
# the expression to the right-hand side of `=` with some other AWS region
# where you want the resources to be deployed to
export TF_VAR_aws_region=$(aws configure get region)

# Just set this to `prod` unconditionally
export TF_VAR_stack_env=prod
```

If you don't have remote `terraform` backend initialized yet we highly recommend
using it to persist the `terraform` state there instead of your local filesystem.
To initialize the remote backend you do the following steps once:

```bash
# Set this to the path where you've untarred the downloaded artifacts
export ARTIFACTS_PATH='/path/to/untarred/artifacts'

cd "$ARTIFACTS_PATH/deployment/global/terraform_remote_backend"

# This uses local terraform state which is fine because these resources
# should be created only once and never be destroyed afterwards
terraform init
terraform apply
```

Once you have the remote terraform backend initialized you may deploy the
stack itself:

```bash
cd "$ARTIFACTS_PATH/deployment/aws-reds"

# Be sure to pass the remote backend configurations
terraform init \
  -backend-config "bucket=elastio-${TF_VAR_stack_env}-${TF_VAR_stack_name}-terraform-state" \
  -backend-config "region=$TF_VAR_aws_region" \
  -backend-config "dynamodb_table=elastio-${TF_VAR_stack_env}-${TF_VAR_stack_name}-terraform-locks" \
  -backend-config "encrypt=true"

# Deploy the stack to your account
terraform apply
```

## Remove deployed Red Stack

To destroy the stack you should `cd` into the artifacts subdirectory `deployment/aws-reds`
and run `terraform destroy` from there.

You might be asked to input some variables (if you haven't set them via `TF_VAR_*` env vars yet):
- `stack_env` should be set to `prod`.
- `stack_name` should be set to the identifier you passed as `--stack-name`
- `aws_region` should be passed explicitly (otherwise it is `us-east-2` by default)
