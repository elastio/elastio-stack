import * as iam from "../iam";

/**
 * Use the following command to discover what resource types are deployed by
 * Elastio Asset Account stack:
 *
 * ```bash
 * aws cloudformation list-stack-resources --stack-name {stack_name} \
 *  | jq '.StackResourceSummaries | map(.ResourceType) | unique'
 * ```
 *
 * This policy is designed to be used for the StackSet execution role:
 * https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-prereqs-self-managed.html
 */
export default {
  description: "Permissions required to deploy the Elastio Asset Account stack",
  statements: [
    {
      Action: ["lambda:*", "cloudformation:*", "logs:*", "ssm:*", "kms:*"],
      Resource: "*",
    },
    {
      Sid: "ElastioIamRead",
      Action: [
        "iam:GetRole",
        "iam:GetRolePolicy",

        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:ListRoles",
        "iam:ListPolicyVersions",

        "iam:ListRoleTags",
        "iam:ListPolicyTags",
      ],
      Resource: "*",
    },
    {
      Sid: "ElastioIamCreate",
      Action: ["iam:CreateRole", "iam:CreatePolicy"],
      Resource: "*",
      Condition: iam.hasRequestTag("elastio:resource"),
    },
    {
      Sid: "ElastioIamUpdate",
      Action: [
        // Roles
        "iam:UpdateRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:UpdateRoleDescription",

        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",

        "iam:PutRolePermissionsBoundary",
        "iam:DeleteRolePermissionsBoundary",

        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",

        "iam:TagRole",
        "iam:UntagRole",

        // Managed Policies
        "iam:CreatePolicyVersion",
        "iam:DeletePolicyVersion",

        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:SetDefaultPolicyVersion",

        "iam:TagPolicy",
        "iam:UntagPolicy",
      ],
      Resource: "*",
      Condition: iam.hasResourceTag("elastio:resource"),
    },
    {
      Sid: "ElastioIamDelete",
      Action: ["iam:DeleteRole", "iam:DeletePolicy"],

      // A name wildcard is required here because if Cloudformation tries to delete
      // a non-existing resource with a Condition based on `elastio:resource` tag,
      // then it'll get a 403 AccessDenied error which it doesn't handle properly.
      // It stops the stack deletion process in a DELETE_FAILED state:
      //
      // ```
      // "User: arn:aws:sts::{account}:assumed-role/AWSCloudFormationStackSetExecutionRole/{session}
      // is not authorized to perform: iam:DeleteRole on resource:
      // role ElastioAssetAccountCfnDeploymentNotifier because no identity-based
      // policy allows the iam:DeleteRole action (Service: Iam, Status Code: 403...
      // ```
      Resource: [
        "arn:*:iam::*:role/*Elastio*",
        "arn:*:iam::*:policy/*Elastio*",
      ],
    },
    {
      Sid: "ElastioIamPassRole",
      // PassRole doesn't support tag-based conditions
      Action: "iam:PassRole",
      Resource: ["arn:*:iam::*:role/*Elastio*"],
    },
  ],
} satisfies iam.Policy;
