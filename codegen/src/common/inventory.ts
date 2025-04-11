import * as iam from "./iam";

/**
 * Permissions for reading inventory shared across lambas, background jobs,
 * ElastioTenant (Connector Account) and CloudConnector (Asset Account) roles.
 */
export const policy: Record<string, InventoryIamPolicyStatement[]> = {
  ReadInventory: [
    {
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

        // Misc. This won't be used at the time of this writing, but
        // may come in handy in the future?
        "backup:ListProtectedResources",
        "backup:ListProtectedResourcesByBackupVault",

        "elasticfilesystem:DescribeFileSystems",
        "elasticfilesystem:ListTagsForResource",
        "elasticfilesystem:DescribeTags",

        "fsx:DescribeVolumes",
        "fsx:DescribeBackups",
        "fsx:DescribeFileSystems",
        "fsx:DescribeStorageVirtualMachines",
        "fsx:ListTagsForResource",

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

        "ec2:DescribeInstances",
        "ec2:DescribeImages",
        "ec2:DescribeHosts",
        "ssm:DescribeInstanceInformation",

        // Used for network config troubleshooting
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "ec2:DescribeRouteTables",
        "ec2:DescribeNatGateways",
        "ec2:DescribeVpcEndpoints",

        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation",
        "s3:GetBucketTagging",
        "s3:GetBucketObjectLockConfiguration",
        "s3:GetBucketAcl",
        "s3:GetBucketVersioning",
        "s3:GetBucketPolicy",
        "s3:GetBucketLogging",
        "s3:ListBucket",

        "iam:ListAccountAliases",
        "ec2:DescribeRegions",
        "kms:DescribeKey",

        // Required for discovering Elastio CFN stack version by blue stack
        // Also used by used by the `accs` service to validate the status
        // of the asset account CFN stack in cross-account scenario (this policy
        // is reused when defining permissions for the connector role in asset account)
        "cloudformation:DescribeStacks",
        "cloudformation:DescribeStackSet",
        "cloudformation:ListStacks",

        // Just for debugging
        "batch:DescribeComputeEnvironments",
        "batch:DescribeJobDefinitions",
        "batch:DescribeJobQueues",
        "batch:DescribeJobs",
        "batch:DescribeSchedulingPolicies",

        "batch:GetJobQueueSnapshot",

        "batch:ListJobs",
        "batch:ListSchedulingPolicies",
        "batch:ListTagsForResource",

        "drs:DescribeRecoverySnapshots",
        "drs:DescribeSourceServers",
        "drs:ListTagsForResource",
      ],
      Resource: "*",
    },
  ],
};

/**
 * Allow just the readonly actions. Make sure the policy doesn't compile if we
 * specify some mutating actions.
 */
type InventoryIamActionPrefix = "List" | "Get" | "Describe";

type InventoryIamAction = Extract<
  iam.Action,
  `${string}:${InventoryIamActionPrefix}${string}`
>;

type InventoryIamPolicyStatement = Omit<iam.PolicyStatement, "Action"> & {
  Action: InventoryIamAction | InventoryIamAction[];
};
