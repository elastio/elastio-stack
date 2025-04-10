import { ArkErrors } from "arktype";
import { inputs, InputsIn } from "./inputs";
import * as mir from "./mir";
import * as tf from "./orchestrator/terraform";

export { inputs };

export function generate(inputsIn: InputsIn) {
  const result = inputs(inputsIn);

  if (result instanceof ArkErrors) {
    throw new Error(`Invalid inputs: ${result}`);
  }

  const resources = mir.resources(result);

  tf.generate(resources);
}

generate({
  connectorAccountId: "123456789012",
  connectorRoleExternalId: "external-id",
});
