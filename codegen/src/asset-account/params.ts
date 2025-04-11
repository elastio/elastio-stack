import { type } from "arktype";
import { collapse } from "../common/string";

const IamPolicyArn = type(/^arn:aws:iam::[^:]*:policy\/.*/);

const CommonParams = type({
  connectorAccountId: type(/^\d{12}$/).configure({
    title: "Cloud connector AWS account ID",
    description: collapse`
      The ID of the Elastio Connector's account that should scan assets
      in this account. It will be trusted to assume the role in this
      account to read the assets and create snapshots.
    `,
  }),

  connectorRoleExternalId: type("string").configure({
    title: "Connector IAM role external ID",
    description: collapse`
      The secret token generated specifically for this account that
      authenticates the source Elastio Connector to assume the
      ElastioCloudConnector role in this account
    `,
    actual: "",
  }),

  tags: type({ "[string]": "string" })
    .configure({
      title: "Tags",
      description: collapse`
        Tags to add to all resources deployed by this stack.
      `,
    })
    .default(() => ({})),

  iamResourceNamesPrefix: type("string")
    .configure({
      title: "IAM resource names prefix",
      description:
        "Add a custom prefix to names of all IAM resources deployed by this stack",
    })
    .default(""),

  iamResourceNamesSuffix: type("string")
    .configure({
      title: "IAM resource names suffix",
      description:
        "Add a custom suffix to names of all IAM resources deployed by this stack",
    })
    .default(""),

  globalManagedPolicies: IamPolicyArn.array()
    .configure({
      title: "Global IAM managed policies ARNs",
      description:
        "IAM managed policies ARNs to attach to all Elastio IAM roles",
    })
    .narrow((list, ctx) => {
      const unique = new Set(list);
      return (
        unique.size === list.length || ctx.mustBe("a list without diplicates")
      );
    })
    .default(() => []),

  globalPermissionBoundary: IamPolicyArn.configure({
    title: "Global IAM permission boundary policy ARN",
    description: collapse`
      The ARN of the IAM managed policy to use as a
      permission boundary for all Elastio IAM roles
    `,
  }).optional(),
});

export const CloudformationParams = CommonParams.merge({
  orchestrator: "'cloudformation'",

  disableDeploymentNotification: type("boolean")
    .configure({
      title: "Deployment Notification",
      description: collapse`
        Send a deployment notification to the Elastio Connector
        account. This is required for the connector to be able to
        discover the assets in this account.
      `,
    })
    .default(false),

  deploymentNotificationToken: type("string")
    .configure({
      title: "Deployment notification token",
      description: collapse`
        Token sent to the SNS topic to authenticate the deployment notification.
      `,
      actual: "",
    })
    .optional(),

  deploymentNotificationSnsTopicArn: type("string")
    .configure({
      title: "Deployment notification SNS topic ARN",
      description: collapse`
        ARN of the Elastio tenant SNS topic where to publish a notification about a
        completed stack deployment.
      `,
    })
    .optional(),

  encryptWithCmk: type("boolean")
    .configure({
      title: "Encrypt data with customer-managed KMS keys",
      description: collapse`
        Provision additional customer-managed KMS keys to encrypt
        Lambda environment variables, DynamoDB tables, S3. Note that
        by default data is encrypted with AWS-managed keys. Enable this
        option only if your compliance requirements mandate the usage of CMKs.
        If this option is disabled Elastio creates only 1 CMK per region where
        the Elastio Connector stack is deployed. If this option is enabled then
        Elastio creates 1 KMS key per AWS account and 2 KMS keys per every AWS
        region where Elastio is deployed in your AWS Account
      `,
    })
    .default(false),

  lambdaTracing: type("boolean")
    .configure({
      title: "Enable AWS X-Ray tracing for Lambda functions",
      description:
        "This increases the cost of the stack. Enable only if needed",
    })
    .default(false),
}).describe("Params specific to CloudFormation orchestrator");

export const TerraformParams = CommonParams.describe(
  "Params specific to Terraform orchestrator",
);
