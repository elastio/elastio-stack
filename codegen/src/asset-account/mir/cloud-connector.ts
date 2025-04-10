import * as iam from "../../common/iam";
import * as inventory from "../../common/inventory";
import { Inputs } from "../inputs";
import _ from "lodash";
import { IamRole } from "./resource";

export function cloudConnectorRole(inputs: Inputs): IamRole {
  const otherStatements: Record<string, iam.PolicyStatement[]> = {
    WriteEc2: [
      // Create and copy snapshots to the cloud connector account
      {
        Action: [
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:CopySnapshot",
        ],
        Resource: ["*"],
      },
      {
        Action: [
          "ec2:DeleteSnapshot",

          // This is used in AWS Backup restore test scenario
          "ec2:StopInstances",
          "ec2:TerminateInstances",

          // Allows additional tags for elastio resources.
          // It's used, for example, to add new tag on a
          // snapshot which indicates that it's clean or infected
          "ec2:CreateTags",
          "ec2:DeleteTags",
        ],
        Resource: ["*"],
        Condition: iam.hasResourceTag("elastio:resource"),
      },

      {
        Action: ["ec2:ModifySnapshotAttribute"],
        Resource: ["*"],

        Condition: {
          // Needed to add createVolumePermission for the connector account.
          StringEquals: {
            "ec2:Add/userId": inputs.connectorAccountId,
            // Even though EC2 IAM reference says there are two more
            // things that could be used in the condition:
            // "ec2:Attribute" and "ec2:Attribute/${AttributeName}",
            // none of them are actually present when the request
            // is evaluated. This can be seen by adding a condition like
            // "ec2:Attribute": "createVolumePermission" and observing
            // an error with an encoded authorization message, that
            // shows the real evaluation context when decoded.
          },
        },
      },

      // This is used in AWS Backup restore test scenario to mutate
      // the created temporary instance/volumes
      {
        Action: [
          "ec2:ModifyInstanceAttribute",
          "ec2:CreateTags",
          "ec2:DeleteTags",
        ],
        Resource: ["*"],
        Condition: iam.hasResourceTag("awsbackup-restore-test"),
      },

      // Allow assigning tags when creating new resources
      {
        Action: ["ec2:CreateTags"],
        Resource: ["arn:aws:ec2:*:*:volume/*", "arn:aws:ec2:*::snapshot/*"],
        Condition: {
          StringLike: {
            "ec2:CreateAction": "*",
          },
        },
      },
      {
        Action: ["ssm:SendCommand"],
        Resource: [
          "arn:aws:ssm:*:*:document/AWSEC2-CreateVssSnapshot",
          "arn:aws:ec2:*:*:instance/*",
        ],
      },
      {
        Action: [
          "ssm:GetConnectionStatus",
          "ssm:GetCommandInvocation",
          "ssm:ListCommands",
        ],
        Resource: ["*"],
      },
    ],

    ReadEbs: [
      {
        Action: ["ebs:ListSnapshotBlocks", "ebs:GetSnapshotBlock"],
        Resource: ["*"],
      },
    ],

    ReadSsm: [
      // Required to be able to try to do app-consistent snapshots
      // of EC2 Windows (VSS snapshots).
      {
        Action: ["ssm:GetParameters", "ssm:GetParameter"],
        Resource: [
          `arn:aws:ssm:*:{{account_id}}:parameter/elastio/*`,
          `arn:aws:ssm:*::parameter/aws/*`,
        ],
      },
    ],

    ReadIam: [
      {
        Action: ["iam:GetInstanceProfile", "iam:SimulatePrincipalPolicy"],
        Resource: ["*"],
      },
    ],

    WriteCloudformation: [
      {
        Action: ["cloudformation:CreateStack", "cloudformation:UpdateStack"],
        Resource: [`arn:aws:cloudformation:*:{{account_id}}:stack/elastio-*/*`],
        Condition: {
          StringEquals: {
            ["cloudformation:RoleArn"]:
              "{{aws_iam_role.asset_region_stack_deployer.arn}}",
          },
        },
      },
      {
        // Allows running cloudformation:CreateStack/UpdateStack
        // on behalf of `asset_region_stack_deployer` role.
        Action: ["iam:PassRole"],
        Resource: ["{{aws_iam_role.asset_region_stack_deployer.arn}}"],
      },
      {
        Action: ["cloudformation:TagResource"],
        Resource: [`arn:aws:cloudformation:*:{{account_id}}:stack/elastio-*/*`],
        Condition: {
          StringLike: {
            "ec2:CreateAction": "*",
          },
        },
      },
      {
        Action: [
          // We need to delete the asset region stack
          "cloudformation:DeleteStack",
          "cloudformation:TagResource",
          "cloudformation:UntagResource",
        ],
        Resource: [`arn:aws:cloudformation:*:{{account_id}}:stack/elastio-*/*`],
        Condition: iam.hasResourceTag("elastio:resource"),
      },
    ],

    ReadS3: [
      {
        Action: [
          // These are actually used by the scan job at the time of this writing
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:GetObject",
          "s3:GetBucketTagging",

          // These permissions were used at the time when we supported native Elastio
          // backups and restores. These are readonly, and they are left here for
          // the future when we might need them or for easier debugging.
          "s3:GetReplicationConfiguration",
          "s3:GetMetricsConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:GetInventoryConfiguration",
          "s3:GetIntelligentTieringConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketWebsite",
          "s3:GetBucketVersioning",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketPolicy",
          "s3:GetBucketOwnershipControls",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketNotification",
          "s3:GetBucketLogging",
          "s3:GetBucketLocation",
          "s3:GetBucketAcl",
          "s3:GetAnalyticsConfiguration",
          "s3:GetAccelerateConfiguration",
        ],
        Resource: ["*"],
      },
    ],

    ReadSqs: [
      {
        // Read the S3 changelog SQS queue
        Action: ["sqs:ReceiveMessage", "sqs:DeleteMessage"],
        Resource: ["*"],
        Condition: iam.hasResourceTag("elastio:resource"),
      },
    ],

    ReadDrs: [
      {
        Action: [
          "drs:DescribeRecoverySnapshots",
          "drs:DescribeSourceServers",
          "drs:ListTagsForResource",
        ],
        Resource: ["*"],
      },
    ],

    ReadKms: [allowKms()],
  };

  const statements = _.mergeWith(
    inventory.policy,
    otherStatements,
    (dest, _src, key) => {
      if (dest !== undefined) {
        throw new Error(
          `Duplicate policy statements in cloud connector policy at ${key}`,
        );
      }
    },
  );

  return {
    type: "aws_iam_role",
    name: "ElastioCloudConnector",
    description:
      "Allows Elastio Cloud Connector to access the assets in this account",

    assumeRolePolicy: {
      Action: ["sts:AssumeRole"],

      Principal: {
        AWS:
          `arn:aws:iam::${inputs.connectorAccountId}:role/` +
          inputs.iamResourceNamesPrefix +
          "ElastioCloudConnectorBastion" +
          inputs.iamResourceNamesSuffix,
      },

      Condition: {
        StringEquals: {
          "sts:ExternalId": inputs.connectorRoleExternalId,
        },
      },
    },

    statements,
  };
}

/**
 * KMS actions needed to decrypt the data encrypted with the KMS key.
 * This is used to decrypt data stored on EBS volumes and S3 buckets
 * encrypted with a custom customer-managed KMS, for example.
 *
 * We explicitly add these permissions to our roles' IAM policies. Then we expect
 * users to add a special tag `elastio:authorize` to their KMS keys to grant Elastio
 * access to their KMS keys. The users also need to setup a KMS key resource-based
 * policy that enables the AWS account where Elastio is deployed managing access
 * via IAM policies through a KMS key policy like this:
 *
 * ```json
 * {
 *   "Sid": "Enable IAM User Permissions",
 *   "Effect": "Allow",
 *   "Principal": {
 *     "AWS": "arn:aws:iam::111122223333:root"
 *   },
 *   "Action": "kms:*",
 *   "Resource": "*"
 * }
 * ```
 * This is taken from [AWS docs](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-root-enable-iam).
 *
 * Note that KMS resource-based policies similar to IAM role trust policies (which
 * also qualify as resource-based policies) are exceptional in their behavior.
 * See the excerpt from the AWS docs below about KMS key resource-based policies:
 *
 * > When the principal in a key policy statement is the account principal,
 * > the policy statement doesn't give any IAM principal permission to use the
 * > KMS key. Instead, it allows the account to use IAM policies to delegate
 * > the permissions specified in the policy statement. This default key policy
 * > statement allows the account to use IAM policies to delegate permission for
 * > all actions (kms:*) on the KMS key.
 *
 * # Cross account scenario
 *
 * Note that IAM acts differently when cross-account access is involved in a general case.
 * However, KMS with its exceptional behavior already acts similar to the cross-account
 * scenario even within the same account, because it requires the resource-based policy
 * to allow the direct principal to use the KMS key, or allow the entire root account
 * principal and require the IAM role to have the identity-based policy that allows
 * the KMS action.
 *
 * See details in the [issue comment](https://github.com/elastio/elastio/issues/9220#issuecomment-2110983526)
 */
export function allowKms(): iam.PolicyStatement {
  return {
    Action: [
      // These actions are needed to reencrypt the volumes that were encrypted
      // by the KMS key.
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
      "kms:CreateGrant",
      "kms:Encrypt",

      // This action is needed to describe the KMS key.
      // Needed only for some cases. For example, when we want to backup and EBS volume
      // that was created from a snapshot of the root volume of an EC2 instance.
      // These calls are made by the ebs.amazonaws.com and not by our code.
      "kms:DescribeKey",

      // GenerateDataKeyWithoutPlaintext in particular is required in case when
      // we create a volume from an unencrypted snapshot but there is a default
      // KMS encryption key set in EBS for the volume.
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",

      // This is required when reading S3 buckets encrypted with a KMS key
      "kms:Decrypt",
    ],

    Resource: ["*"],

    // Users need to put a special tag `elastio:authorize` on their KMS keys to
    // allow Elastio to use them for decrypting their data. We also allow
    // access to Elastio-owned keys marked with the `elastio:resource` tag.
    Condition: {
      StringLike: {
        ...iam.hasResourceTag("elastio:authorize").StringLike,
        ...iam.hasResourceTag("elastio:resource").StringLike,
      },
    },
  };
}
