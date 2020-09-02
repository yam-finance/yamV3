// ============ Contracts ============

// Token
// deployed first
const YAMImplementation = artifacts.require("YAMDelegate");
const YAMProxy = artifacts.require("YAMDelegator");

// ============ Main Migration ============

const migration = async (deployer, network, accounts) => {
  await Promise.all([
    deployToken(deployer, network),
  ]);
};

module.exports = migration;

// ============ Deploy Functions ============


async function deployToken(deployer, network) {
  await deployer.deploy(YAMImplementation);
  if (network != "mainnet") {
    await deployer.deploy(YAMProxy,
      "YAM",
      "YAM",
      18,
      "0", // print extra few mil for user
      YAMImplementation.address,
      "0x"
    );
  } else {
    await deployer.deploy(YAMProxy,
      "YAM",
      "YAM",
      18,
      "0",
      YAMImplementation.address,
      "0x"
    );
  }

}
