import * as tfModulesDocs from './tf-modules-docs';
import * as assetAccount from './asset-account';

async function main() {
  await tfModulesDocs.generate();

  await assetAccount.generate({
    connectorAccountId: "123456789012",
    connectorRoleExternalId: "external-id",
  });
}

main();
