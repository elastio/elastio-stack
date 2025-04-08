// import { Construct } from "constructs";
// import { CfnCondition, Fn, aws_iam as iam, aws_ssm as ssm } from "aws-cdk-lib";
// import * as condition from "../common/iam/condition";
// import { version } from "../common/version";
// import { Aws, CfnOutput, Stack, StackProps } from "aws-cdk-lib";
// import { DeploymentNotifier } from "../common/deployment-notifier";
// import { InputParam } from "../common/input-param";
// import { Globals, MaybeEmpty } from "../common/globals";
// import { KmsEncryptionKey } from "../common/kms";
// import { allowKms, createRole, IamRoleProps } from "../common/iam";
import * as inventory from "../common/inventory";
import { Input } from "../common/inputs";
import { collapse } from "../common/string";
// import _ from "lodash";

const iamPolicyArnRegex = "^arn:aws:iam::[^:]*:policy/.*";

export const inputs = {
  cloudConnectorAccountId: {
    group: "internal",
    displayName: "Cloud connector AWS account ID",
    description: collapse`
      The ID of the Elastio Connector's account that should scan assets
      in this account. It will be trusted to assume the role in this
      account to read the assets and create snapshots.
    `,
    default: null,
    type: "string",
  },
  cloudConnectorRoleExternalId: {
    group: "internal",
    displayName: "Connector IAM role external ID",
    description: collapse`
      The secret token generated specifically for this account that
      authenticates the source Elastio Connector to assume the
      ElastioCloudConnector role in this account
    `,
    default: "",
    type: "string",
  },
  iamResourceNamesPrefix: {
    group: "configurable",
    displayName: "IAM resource names prefix",
    description:
      "Add a custom prefix to names of all IAM resources deployed by this stack",
    type: "string",
    default: "",
  },

  iamResourceNamesSuffix: {
    group: "configurable",
    displayName: "IAM resource names suffix",
    description:
      "Add a custom suffix to names of all IAM resources deployed by this stack",
    type: "string",
    default: "",
  },

  globalManagedPolicies: {
    group: "configurable",
    displayName: "Global IAM managed policies ARNs",
    description: "IAM managed policies ARNs to attach to all Elastio IAM roles",
    default: null,
    type: "set(string)",
    allowedPattern: iamPolicyArnRegex,
  },

  globalPermissionBoundary: {
    group: "configurable",
    displayName: "Global IAM permission boundary policy ARN",
    description: collapse`
      The ARN of the IAM managed policy to use as a
      permission boundary for all Elastio IAM roles
    `,
    type: "string",
    default: "",
    allowedPattern: iamPolicyArnRegex,
  },

  encryptWithCmk: {
    group: "configurable",
    displayName: "Encrypt data with customer-managed KMS keys",
    type: "bool",
    default: false,
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
  },

  lambdaTracing: {
    group: "configurable",
    displayName: "Enable AWS X-Ray tracing for Lambda functions",
    description: "This increases the cost of the stack. Enable only if needed",
    type: "bool",
    default: false,
  },
} satisfies Record<string, Input>;

// this.globals = new Globals({
//   stackName: "AssetAccount",
//   iamPrefix: iamResourceNamesPrefix.valueAsString,
//   iamSuffix: iamResourceNamesSuffix.valueAsString,
//   globalManagedPolicies: MaybeEmpty.fromListInput(globalManagedPolicies),
//   globalPermissionBoundary: MaybeEmpty.fromStringInput(
//     globalPermissionBoundary,
//   ),
//   kmsEncryptionKey: new KmsEncryptionKey(
//     this,
//     "kmsEncryptionKey",
//     encryptWithCmk,
//     "alias/elastio-asset-account-encryption",
//   ).key,
//   lambdaTracing: new CfnCondition(this, "lambdaTracingCondition", {
//     expression: Fn.conditionEquals(lambdaTracing, "true"),
//   }),
// });

// new DeploymentNotifier({
//   scope: this,
//   id: "deploymentNotifier",
//   globals: this.globals,
//   payload: {
//     stackKind: "asset",
//     stackVersion: version.asset_account,
//     accountId: Aws.ACCOUNT_ID,
//     cloudConnectorAccountId,
//   },
// });

// new ssm.StringParameter(this, "assetAccountStackName", {
//   parameterName: "/elastio/asset/account/stack-name",
//   description:
//     "The name of the Asset Account CloudFormation stack used " +
//     "for discovery by the Cloud Connector",
//   stringValue: Aws.STACK_NAME,
// });

// const inventoryEventTargetRole = this.createRole({
//   id: "inventoryEventTarget",
//   name: "InventoryEventTarget",
//   assumedBy: new iam.ServicePrincipal("events.amazonaws.com"),
//   statements: [
//     {
//       actions: ["events:PutEvents"],
//       resources: [
//         `arn:aws:events:*:${cloudConnectorAccountId.valueAsString}:event-bus/elastio-*`,
//       ],
//     },
//   ],
// });

// const assetRegionStackDeployerRole = this.createRole({
//   id: "assetRegionStackDeployer",
//   name: "AssetRegionStackDeployer",
//   description: "Used by Cloudformation to deploy region-level stack",
//   assumedBy: new iam.ServicePrincipal("cloudformation.amazonaws.com"),
//   statements: [
//     {
//       actions: [
//         "events:DescribeRule",
//         "events:ListTargetsByRule",
//         "events:ListTagsForResource",
//         "events:PutRule",
//         "events:PutTargets",
//         "events:RemoveTargets",
//         "events:DeleteRule",
//         "events:EnableRule",
//         "events:DisableRule",
//       ],
//       resources: [`arn:aws:events:*:${Aws.ACCOUNT_ID}:rule/elastio-*`],
//     },
//     {
//       actions: [
//         // Allows assigning of `inventoryEventTargetRole` role
//         // to the event targets
//         "iam:PassRole",
//       ],
//       resources: [inventoryEventTargetRole.roleArn],
//     },
//   ],
// });

// const cloudConnectorStatements: Record<string, iam.PolicyStatementProps[]> =
//   {
//     WriteEc2: [
//       // Create and copy snapshots to the cloud connector account
//       {
//         actions: [
//           "ec2:CreateSnapshot",
//           "ec2:CreateSnapshots",
//           "ec2:CopySnapshot",
//         ],
//         resources: ["*"],
//       },
//       {
//         actions: [
//           "ec2:DeleteSnapshot",

//           // This is used in AWS Backup restore test scenario
//           "ec2:StopInstances",
//           "ec2:TerminateInstances",

//           // Allows additional tags for elastio resources.
//           // It's used, for example, to add new tag on a
//           // snapshot which indicates that it's clean or infected
//           "ec2:CreateTags",
//           "ec2:DeleteTags",
//         ],
//         resources: ["*"],
//         conditions: condition.hasResourceTag("elastio:resource"),
//       },

//       {
//         actions: ["ec2:ModifySnapshotAttribute"],
//         resources: ["*"],

//         conditions: {
//           // Needed to add createVolumePermission for the connector account.
//           StringEquals: {
//             "ec2:Add/userId": cloudConnectorAccountId.valueAsString,
//             // Even though EC2 IAM reference says there are two more
//             // things that could be used in the condition:
//             // "ec2:Attribute" and "ec2:Attribute/${AttributeName}",
//             // none of them are actually present when the request
//             // is evaluated. This can be seen by adding a condition like
//             // "ec2:Attribute": "createVolumePermission" and observing
//             // an error with an encoded authorization message, that
//             // shows the real evaluation context when decoded.
//           },
//         },
//       },

//       // This is used in AWS Backup restore test scenario to mutate
//       // the created temporary instance/volumes
//       {
//         actions: [
//           "ec2:ModifyInstanceAttribute",
//           "ec2:CreateTags",
//           "ec2:DeleteTags",
//         ],
//         resources: ["*"],
//         conditions: condition.hasResourceTag("awsbackup-restore-test"),
//       },

//       // Allow assigning tags when creating new resources
//       {
//         actions: ["ec2:CreateTags"],
//         resources: [
//           "arn:aws:ec2:*:*:volume/*",
//           "arn:aws:ec2:*::snapshot/*",
//         ],
//         conditions: {
//           StringLike: {
//             "ec2:CreateAction": "*",
//           },
//         },
//       },
//       {
//         actions: ["ssm:SendCommand"],
//         resources: [
//           "arn:aws:ssm:*:*:document/AWSEC2-CreateVssSnapshot",
//           "arn:aws:ec2:*:*:instance/*",
//         ],
//       },
//       {
//         actions: [
//           "ssm:GetConnectionStatus",
//           "ssm:GetCommandInvocation",
//           "ssm:ListCommands",
//         ],
//         resources: ["*"],
//       },
//     ],
//     ReadEbs: [
//       {
//         actions: ["ebs:ListSnapshotBlocks", "ebs:GetSnapshotBlock"],
//         resources: ["*"],
//       },
//     ],
//     ReadSsm: [
//       // Required to be able to try to do app-consistent snapshots
//       // of EC2 Windows (VSS snapshots).
//       {
//         actions: ["ssm:GetParameters", "ssm:GetParameter"],
//         resources: [
//           `arn:aws:ssm:*:${Aws.ACCOUNT_ID}:parameter/elastio/*`,
//           `arn:aws:ssm:*::parameter/aws/*`,
//         ],
//       },
//     ],
//     ReadIam: [
//       {
//         actions: ["iam:GetInstanceProfile", "iam:SimulatePrincipalPolicy"],
//         resources: ["*"],
//       },
//     ],
//     WriteCloudformation: [
//       {
//         actions: [
//           "cloudformation:CreateStack",
//           "cloudformation:UpdateStack",
//         ],
//         resources: [
//           `arn:aws:cloudformation:*:${Aws.ACCOUNT_ID}:stack/elastio-*/*`,
//         ],
//         conditions: {
//           StringEquals: {
//             ["cloudformation:RoleArn"]:
//               assetRegionStackDeployerRole.roleArn,
//           },
//         },
//       },
//       {
//         // Allows running cloudformation:CreateStack/UpdateStack
//         // on behalf of `assetRegionStackDeployer` role.
//         actions: ["iam:PassRole"],
//         resources: [assetRegionStackDeployerRole.roleArn],
//       },
//       {
//         actions: ["cloudformation:TagResource"],
//         resources: [
//           `arn:aws:cloudformation:*:${Aws.ACCOUNT_ID}:stack/elastio-*/*`,
//         ],
//         conditions: {
//           StringLike: {
//             "ec2:CreateAction": "*",
//           },
//         },
//       },
//       {
//         actions: [
//           // We need to delete the asset region stack
//           "cloudformation:DeleteStack",
//           "cloudformation:TagResource",
//           "cloudformation:UntagResource",
//         ],
//         resources: [
//           `arn:aws:cloudformation:*:${Aws.ACCOUNT_ID}:stack/elastio-*/*`,
//         ],
//         conditions: condition.hasResourceTag("elastio:resource"),
//       },
//     ],
//     ReadS3: [
//       {
//         actions: [
//           // These are actually used by the scan job at the time of this writing
//           "s3:ListBucket",
//           "s3:GetObjectVersion",
//           "s3:GetObject",
//           "s3:GetBucketTagging",

//           // These permissions were used at the time when we supported native Elastio
//           // backups and restores. These are readonly, and they are left here for
//           // the future when we might need them or for easier debugging.
//           "s3:GetReplicationConfiguration",
//           "s3:GetMetricsConfiguration",
//           "s3:GetLifecycleConfiguration",
//           "s3:GetInventoryConfiguration",
//           "s3:GetIntelligentTieringConfiguration",
//           "s3:GetEncryptionConfiguration",
//           "s3:GetBucketWebsite",
//           "s3:GetBucketVersioning",
//           "s3:GetBucketRequestPayment",
//           "s3:GetBucketPublicAccessBlock",
//           "s3:GetBucketPolicy",
//           "s3:GetBucketOwnershipControls",
//           "s3:GetBucketObjectLockConfiguration",
//           "s3:GetBucketNotification",
//           "s3:GetBucketLogging",
//           "s3:GetBucketLocation",
//           "s3:GetBucketAcl",
//           "s3:GetAnalyticsConfiguration",
//           "s3:GetAccelerateConfiguration",
//         ],
//         resources: ["*"],
//       },
//     ],
//     ReadSqs: [
//       {
//         // Read the S3 changelog SQS queue
//         actions: ["sqs:ReceiveMessage", "sqs:DeleteMessage"],
//         resources: ["*"],
//         conditions: condition.hasResourceTag("elastio:resource"),
//       },
//     ],
//     ReadDrs: [
//       {
//         actions: [
//           "drs:DescribeRecoverySnapshots",
//           "drs:DescribeSourceServers",
//           "drs:ListTagsForResource",
//         ],
//         resources: ["*"],
//       },
//     ],
//     // Required by `ModifySnapshotAttributeRequest`, on encrypted snapshots
//     ReadKms: [allowKms()],
//   };

// const statements = _.mergeWith(
//   inventoryIamPolicy,
//   cloudConnectorStatements,
//   (dest, _src, key) => {
//     if (dest !== undefined) {
//       throw new Error(
//         `Duplicate policy statements in cloud connector policy at ${key}`,
//       );
//     }
//   },
// );

// this.createRole({
//   id: "cloudConnector",
//   name: "CloudConnector",
//   description:
//     "Allows Elastio Cloud Connector to access the assets in this account",
//   assumedBy: new iam.ArnPrincipal(
//     `arn:aws:iam::${cloudConnectorAccountId.valueAsString}:role/` +
//       iamResourceNamesPrefix.valueAsString +
//       "ElastioCloudConnectorBastion" +
//       iamResourceNamesSuffix.valueAsString,
//   ),
//   externalIds: [cloudConnectorRoleExternalId.valueAsString],
//   statements,
// });

// new CfnOutput(this, "cfnTemplateVersion", {
//   value: version.asset_account,
// });
