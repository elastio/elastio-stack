import * as iam from "../iam";

export default {
  description: "Allows Elastio to scan AWS Backup recovery points.",

  statements: [
    {
      Sid: "ReadBackupInventory",
      Action: [
        // Vaults
        "backup:ListBackupVaults",
        "backup:DescribeBackupVault",

        // Recovery points
        "backup:ListRecoveryPointsByResource",
        "backup:DescribeRecoveryPoint",
        "backup:ListRecoveryPointsByBackupVault",
        "backup:GetRecoveryPointRestoreMetadata",

        // Common for all resources
        "backup:ListTags",

        // Misc.
        "backup:ListProtectedResources",
        "backup:ListProtectedResourcesByBackupVault",
      ],
      Resource: "*",
    },

    {
      Sid: "ReadEbsInventory",
      Action: [
        // Volumes
        "ec2:DescribeVolumeStatus",
        "ec2:DescribeVolumes",

        // Snapshots
        "ec2:DescribeSnapshots",
        "ec2:DescribeSnapshotAttribute",

        // Common for all resources
        "ec2:DescribeTags",

        // Used for cost estimation
        "ebs:ListSnapshotBlocks",
        "ebs:ListChangedBlocks",
      ],
      Resource: "*",
    },

    {
      Sid: "ReadEbsSnapshotsData",
      Action: ["ebs:GetSnapshotBlock"],
      Resource: "*",
    },

    {
      Sid: "ReadEc2Inventory",
      Action: [
        "ec2:DescribeInstances",
        "ec2:DescribeImages",
        "ec2:DescribeHosts",
        "ssm:DescribeInstanceInformation",
      ],
      Resource: "*",
    },

    {
      Sid: "ShareEbsSnapshot",
      Action: ["ec2:ModifySnapshotAttribute"],
      Resource: "*",
      Condition: {
        // Needed to add createVolumePermission for the sharing the snapshot
        // with the connector account.
        StringLike: {
          "ec2:Add/userId": "*",
        },
      },
    },

    {
      Sid: "KmsAccess",

      // Users need to put a special tag on their KMS keys to allow Elastio
      // use them for decrypting their data. It must be documented in public
      // Elastio documentation.
      Condition: iam.hasResourceTag("elastio:authorize"),

      Action: [
        // These actions are needed to reencrypt the volumes that were encrypted
        // by the KMS key.
        "kms:ReEncryptFrom",
        "kms:ReEncryptTo",
        "kms:CreateGrant",
        "kms:Encrypt",

        // Needed only for some cases. For example, when we want to snapshot an EBS
        // volume that was created from a snapshot of the root volume of an EC2 instance.
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
      Resource: "*",
    },
  ],
} satisfies iam.Policy;
