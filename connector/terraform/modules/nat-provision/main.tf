resource "aws_cloudformation_stack" "this" {
  name = "elastio-nat-provision-lambda"
  template_url = join(
    "/",
    [
      "https://elastio-prod-artifacts-us-east-2.s3.us-east-2.amazonaws.com",
      "contrib/elastio-nat-provision-lambda/${var.template_version}",
      "cloudformation-lambda.yaml"
    ]
  )
  tags = {
    "elastio:resource" = "true"
  }
  capabilities = ["CAPABILITY_NAMED_IAM"]
  parameters = {
    for key, value in var.connector_account_stack.parameters :
    key => value
    if contains(
      [
        "encryptWithCmk",
        "lambdaTracing",
        "globalManagedPolicies",
        "globalPermissionBoundary",
        "iamResourceNamesPrefix",
        "iamResourceNamesSuffix",
      ],
      key
    )
  }
}
