import * as iam from "../../common/iam";

export type Resource = IamRole | SsmParameter;

export type IamRole = {
  type: "aws_iam_role";
  name: string;
  description: string;
  assumeRolePolicy: iam.PolicyStatement;
  statements: Record<string, iam.PolicyStatement[]>;
};

type SsmParameter = {
  type: "aws_ssm_parameter";
  name: string;
  description: string;
  value: string;
};
