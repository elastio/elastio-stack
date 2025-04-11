#########################
## Required parameters ##
#########################

variable "elastio_pat" {
  description = "Personal Access Token generated by the Elastio Portal"
  sensitive   = true
  type        = string
  nullable    = false
}

variable "elastio_tenant" {
  description = "Name of your Elastio tenant. For example `mycompany.app.elastio.com`"
  type        = string
  nullable    = false
}

variable "elastio_cloud_connectors" {
  description = <<DESCR
    List of regions where Cloud Connectors are to be deployed, VPC and subnet(s) to use,
    and other regional configurations (mostly for regulatory compliance).
  DESCR

  type = list(object({
    region = string

    # Should not be set if `network_configuration`
    # is set to `Auto` (which is the default)
    vpc_id     = optional(string)
    subnet_ids = optional(list(string))

    s3_access_logging = optional(object({
      target_bucket = string
      target_prefix = optional(string)

      # Can be one of the following:
      # - SimplePrefix
      # - PartitionedPrefix:EventTime
      # - PartitionedPrefix:DeliveryTime
      target_object_key_format = optional(string)
    }))
  }))

  nullable = false
}

#########################
## Optional parameters ##
#########################

variable "network_configuration" {
  description = <<DESCR
    Can be set to either `Auto` or `Manual`. If set to `Auto`, Elastio will
    automatically create a VPC and subnets in the specified regions for the
    scan clusters to run in.

    If set to `Manual`, you must provide the VPC ID and subnet IDs in the
    `elastio_cloud_connectors` with the network config for each region.
  DESCR

  type     = string
  default  = "Auto"
  nullable = false

  validation {
    condition     = contains(["Auto", "Manual"], var.network_configuration)
    error_message = "network_configuration must be one of 'Auto' or 'Manual'"
  }
}

variable "elastio_nat_provision_stack" {
  description = <<DESCR
    Specifies the version of Elastio NAT provision stack to deploy (e.g. `v5`).

    This is a CloudFormation stack that automatically provisions NAT Gateways in
    your VPC when Elastio worker instances run to provide them with the outbound
    Internet access when Elastio is deployed in private subnets.

    If you don't need this stack (e.g. you already have NAT gateways in your VPC
    or you deploy into public subnets) you can omit this parameter. The default
    value of `null` means there won't be any NAT provision stack deployed.

    The source code of this stack can be found here:
    https://github.com/elastio/contrib/tree/master/elastio-nat-provision-lambda
  DESCR

  type     = string
  nullable = true
  default  = null
}

variable "encrypt_with_cmk" {
  description = <<DESCR
    Provision additional customer-managed KMS keys to encrypt
    Lambda environment variables, DynamoDB tables, S3. Note that
    by default data is encrypted with AWS-managed keys.

    Enable this option only if your compliance requirements mandate the usage of CMKs.

    If this option is disabled Elastio creates only 1 CMK per region where
    the Elastio Connector stack is deployed. If this option is enabled then
    Elastio creates 1 KMS key per AWS account and 2 KMS keys per every AWS
    region where Elastio is deployed in your AWS account.

    If you have `elastio_nat_provision_stack` enabled as well, then 1 more KMS key
    will be created as part of that stack as well (for a total of 3 KMS keys per region).

  DESCR

  type    = bool
  default = null
}

variable "lambda_tracing" {
  description = <<DESCR
    Enable AWS X-Ray tracing for Lambda functions. This increases the cost of
    the stack. Enable only if needed
  DESCR
  type        = bool
  default     = null
}

variable "global_managed_policies" {
  description = "List of IAM managed policies ARNs to attach to all Elastio IAM roles"
  type        = set(string)
  default     = null

  validation {
    condition = alltrue([
      for policy in coalesce(var.global_managed_policies, []) :
      can(regex("^arn:[^:]*:iam::[0-9]+:policy/.+$", policy))
    ])
    error_message = "global_managed_policies must be a list of ARNs"
  }
}

variable "global_permission_boundary" {
  description = "The ARN of the IAM managed policy to use as a permission boundary for all Elastio IAM roles"
  type        = string
  default     = null

  validation {
    condition = (
      var.global_permission_boundary == null ||
      can(regex("^arn:[^:]*:iam::[0-9]+:policy/.+$", var.global_permission_boundary))
    )
    error_message = "global_permission_boundary must be an ARN"
  }
}

variable "iam_resource_names_prefix" {
  description = <<DESCR
    Add a custom prefix to names of all IAM resources deployed by this stack.
    The sum of the length of the prefix and suffix must not exceed 14 characters.
  DESCR

  type    = string
  default = null
}

variable "iam_resource_names_suffix" {
  description = <<DESCR
    Add a custom prefix to names of all IAM resources deployed by this stack.
    The sum of the length of the prefix and suffix must not exceed 14 characters.
  DESCR

  type    = string
  default = null
}

variable "iam_resource_names_static" {
  description = <<DESCR
    If enabled, the stack will use static resource names without random characters in them.

    This parameter is set to `true` by default, and it shouldn't be changed. The older
    versions of Elastio stack used random names generated by CloudFormation for IAM
    resources, which is inconvenient to work with. New deployments that use the terraform
    automation should have this set to `true` for easier management of IAM resources.
  DESCR

  type     = bool
  default  = true
  nullable = false
}

variable "disable_customer_managed_iam_policies" {
  description = <<DESCR
    If this is set to `false` (or omitted), then the stack will create
    additional customer-managed IAM policies that you can attach to your
    IAM identities to grant them direct access to the Elastio Connector stack.
    This way you can use elastio CLI directly to list Elastio scan jobs or
    submit new scan jobs. Set this to `true` if you don't need these policies.
  DESCR

  type    = bool
  default = null
}

variable "service_linked_roles" {
  description = <<DESCR
  By default the CFN stack creates the service-linked IAM roles needed by the stack.
  Since these are global in your account, they can't be defined as regular resources
  in the CFN, because these roles may already exist in your account and thus
  the deployment would fail on a name conflict.

  Instead, by default, they are deployed using an AWS::CloudFormation::CustomResource
  which invokes an AWS Lambda function that creates the service-linked roles only if
  they don't exist and doesn't fail if they do.

  The default approach of creating the service-linked roles via the CFN requires
  creating a lambda function in your environment that has IAM write permission of
  `iam:CreateServiceLinkedRole`. If you can't afford creating such a lambda function
  then set this parameter to `tf` and this terraform module will create the
  service-linked roles without the need for a lambda function.

  If you set this to `tf`, then make sure you have the AWS CLI installed and
  configured with the necessary credentials on the machine where you run terraform.
  DESCR

  type     = string
  default  = "cfn"
  nullable = false

  validation {
    condition     = contains(["cfn", "tf"], var.service_linked_roles)
    error_message = "service_linked_roles must be one of 'cfn', 'tf'"
  }
}

variable "ecr_public_prefix" {
  description = <<DESCR
    Repository prefix for the ECR Public registry. Used to configure a pull-through
    cache for elastio images that are downloaded from ECR Public. You can configure
    your own cache via ECR private, and then specify the repository prefix here.

    This field supports 'account_id' and 'region' interpolation.
    For example, such value can be provided:
    '{{account_id}}.dkr.ecr.{{region}}.amazonaws.com/ecr-public'
  DESCR

  type    = string
  default = null
}
