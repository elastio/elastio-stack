# Service-Managed StackSet Example

This is a basic example of using the `elastio-asset-account-stack-set` terraform module with the service-managed AWS Cloudformation StackSet.

You'll need to deploy it from the AWS Management account. You'll also need to specify both the input variables: `accounts` and `organizational_unit_ids`.

AWS API requires at least one org unit ID that contains the provided accounts. It doesn't mean you'll deploy the StackSet into the entire org unit, it's just a quirk of the AWS API. The Stack set instances will still be deployed into the accounts specified in `accounts`.

If you want to deploy into the entire org unit, then modify the `deployment_targets` as needed for your use case.
