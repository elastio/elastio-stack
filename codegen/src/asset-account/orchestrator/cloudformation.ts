import _ from "lodash";
import * as hclTools from "@cdktf/hcl-tools";
import * as iam from "../../common/iam";
import * as prettier from "prettier";
import { CloudFormationParams } from "../params";
import { Resource } from "../mir";

async function literal(value: unknown): Promise<string> {
  const json = JSON.stringify(value, null, 2);

  const pretty = await prettier.format(json, { parser: "json" });
  return pretty.trim();
}

async function jsonencode(value: unknown): Promise<string> {
  return `jsonencode(\n${await literal(value)}\n)`;
}

function policyDocument(statements: iam.PolicyStatement[]) {
  return {
    Version: "2012-10-17",
    Statement: statements.map((statement) => ({
      Effect: statement.Effect ?? "Allow",
      ...statement,
    })),
  };
}

export type CloudFormationParams = typeof CloudFormationParams.inferOut;

export interface CloudFormationProject {
  files: Record<string, string>;
}

export async function generate(
  resources: Record<string, Resource>,
  params: CloudFormationParams,
): Promise<CloudFormationProject> {
  const parts = [
    `locals {
      tags = ${await literal(params.tags)}
    }`,
  ];

  for (const [id, resource] of Object.entries(resources)) {
    switch (resource.type) {
      case "aws_iam_role": {
        parts.push(
          `resource "aws_iam_role" ${literal(id)} {
            name = ${literal(resource.name)}
            tags = local.tags
            assume_role_policy = ${await jsonencode(policyDocument([resource.assumeRolePolicy]))}
          }`,
        );

        const statements = Object.entries(resource.statements);

        if (statements.length === 0) {
          continue;
        }

        const policies = _.mapValues(
          resource.statements,
          (statement) => policyDocument(statement).Statement,
        );

        parts.push(
          `resource "aws_iam_role_policy" ${literal(id)} {
            role = aws_iam_role.${id}.name
            name = each.key
            policy = jsonencode(
              {
                "Version": "2012-10-17",
                "Statement": each.value
              }
            )
            for_each = ${await literal(policies)}
          }`,
        );
      }
      case "aws_ssm_parameter": {
      }
    }
  }

  parts.push(`
    data "aws_caller_identity" "current" {}
    locals {
      account_id = data.aws_caller_identity.current.account_id
    }
  `);

  const content = parts
    .join("\n\n")
    .replaceAll("{{account_id}}", "${local.account_id}")
    .replaceAll(/\{\{(.*)\}\}/g, "${$1}");

  const formatted = (await hclTools.format(content)).trim();

  console.log(formatted);

  return {
    files: {
      "main.tf": formatted,
    },
  };
}
