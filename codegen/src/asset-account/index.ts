import { ArkErrors } from "arktype";
import { CloudFormationParams, TerraformParams } from "./params";
import * as mir from "./mir";
import * as terraform from "./orchestrator/terraform";
import * as cloudformation from "./orchestrator/cloudformation";

export type CloudFormationParams = typeof CloudFormationParams.inferIn;
export type TerraformParams = typeof TerraformParams.inferIn;

export function generateCloudFormation(paramsIn: CloudFormationParams) {
  const params = CloudFormationParams(paramsIn);
  return generate(params, cloudformation.generate);
}

export function generateTerraform(paramsIn: TerraformParams) {
  const params = TerraformParams(paramsIn);
  return generate(params, terraform.generate);
}

type Generator<P extends mir.Params, R> = (
  resources: Record<string, mir.Resource>,
  params: P,
) => R;

function generate<P extends mir.Params, R, F extends Generator<P, R>>(
  params: P | ArkErrors,
  generator: F,
): R {
  if (params instanceof ArkErrors) {
    throw new Error(`Invalid params: ${params}`);
  }

  const resources = mir.resources(params);

  params.tags["elastio:resource"] = "true";

  return generator(resources, params);
}
