import type * as iam from "aws-iam-policy-types";

/**
 * The name of the policy is the PascalCased version of the policy file name
 * with the `Elastio` prefix.
 */
export interface Policy {
  description: string;
  statements: PolicyStatement[];
}

interface PolicyStatement {
  /**
   * If not specified then `Allow` is assumed.
   */
  Effect?: "Deny";
  Action: Action | Action[];
  Principal?: Principal;
  Resource: string | string[];
  Condition?: Record<string, any>;

  /**
   * Statement ID usually used as a description of the statement.
   */
  Sid?: string;
}

type Principal =
  | "*"
  | {
      AWS: string | string[];
    }
  | {
      Federated: string | string[];
    }
  | {
      Service: string | string[];
    };

type Action =
  | `${string}:*`
  | `${iam.AwsBackupActions}`
  | `${iam.AwsCloudformationActions}`
  | `${iam.AwsEbsActions}`
  | `${iam.AwsEc2Actions}`
  | `${iam.AwsIamActions}`
  | `${iam.AwsKmsActions}`
  | `${iam.AwsLambdaActions}`
  | `${iam.AwsLogsActions}`
  | `${iam.AwsS3Actions}`
  | `${iam.AwsSsmActions}`;

type KnownTag =
  // A simple tag that customers can add to their resource for Elastio to
  // get access to it. It's first use case at the time of this writing is
  // autorizing Elastio access to KMS keys customers use to encrypt their data.
  //
  // This tag can currently be set to a value like an empty string or `true`.
  // However, we may reserve the right to endow special values for this tag
  // with specific behavior. Think of `elastio:authorize=read` or
  // `elastio:authorize=write` giving different level of access to customer's
  // resources. Although today we don't need this because we only read customer's
  // data and don't modify it.
  | "elastio:authorize"

  // Set on every resource deployed by Elastio
  | "elastio:resource"

  // Set by AWS Backup on resources created as part of AWS Backup restore testing.
  // The value of this tag is the ID of the AWS Backup restore job.
  | "awsbackup-restore-test";

export function hasResourceTag(tag: KnownTag) {
  return hasTags("aws:ResourceTag", tag);
}

export function hasRequestTag(tag: KnownTag) {
  return hasTags("aws:RequestTag", tag);
}

function hasTags(kind: string, tag: KnownTag) {
  return {
    StringLike: {
      [`${kind}/${tag}`]: "*",
    },
  };
}
