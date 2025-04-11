# Self-Managed StackSet Example

This is a basic example of using the `elastio-asset-account-stack-set` terraform module with the self-managed AWS CloudFormation StackSet.

You can deploy it even within a single account. Just specify the `template_url` input variable at minimum.

You can specify the `admin_account_aws_profile` and `asset_account_aws_profile` to use separate Admin and Asset accounts. If you don't specify them, then the default AWS account configured in your environment will be used as both the Admin and the Asset account.
