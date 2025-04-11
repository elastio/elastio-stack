import * as fs from "node:fs/promises";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import { Policy } from "./common/iam";

const scriptPath = fileURLToPath(import.meta.url);
const scriptDir = path.dirname(scriptPath);
const iamPoliciesTfModulePath = path.join(
  path.join(scriptDir, "../../iam-policies/terraform"),
);

async function writePolicy(policyName: string, policy: Policy) {
  const policyDocument = {
    Version: "2012-10-17",
    Statement: policy.statements.map((statement) => ({
      ...statement,
      Effect: statement.Effect ?? "Allow",
    })),
  };

  const policyDefinition = {
    Description: policy.description,
    PolicyDocument: policyDocument,
  };

  const policyDocumentJson = JSON.stringify(policyDefinition, null, 2);

  const policyOutputPath = path.join(
    iamPoliciesTfModulePath,
    "policies",
    `${policyName}.json`,
  );

  await fs.writeFile(policyOutputPath, policyDocumentJson);
}

async function generate() {
  const policiesDir = path.join(scriptDir, "policies");
  const policyFiles = await fs.readdir(policiesDir);
  const policyNames = policyFiles.map((file) => path.basename(file, ".ts"));

  const policies = await Promise.all(
    policyNames.map(async (policyName) => {
      const policyPath = path.join(policiesDir, `${policyName}.ts`);
      const module: { default: Policy } = await import(policyPath);
      const policy = module.default;

      await writePolicy(policyName, policy);

      return [policyName, policy] as const;
    }),
  );

  const policiesMdTable = policies
    .map(([policyName, policy]) => {
      const name = `[\`${policyName}\`][${policyName}]`;
      return `| ${name} | ${policy.description} |`;
    })
    .join("\n");

  const links = policies
    .map(
      ([policyName]) =>
        `[${policyName}]: ../../codegen/src/policies/${policyName}.ts`,
    )
    .join("\n");

  const readmePath = path.join(iamPoliciesTfModulePath, "README.md");
  const readme = await fs.readFile(readmePath, "utf-8");

  const docs = `| Policy | Description |\n| --- | --- |\n${policiesMdTable}\n\n${links}`;

  const policiesDocs = readme.replace(
    /<!-- ELASTIO_BEGIN_POLICY_NAMES -->(.*)<!-- ELASTIO_END_POLICY_NAMES -->/s,
    `<!-- ELASTIO_BEGIN_POLICY_NAMES -->\n${docs}\n<!-- ELASTIO_END_POLICY_NAMES -->`,
  );

  await fs.writeFile(readmePath, policiesDocs);
}
