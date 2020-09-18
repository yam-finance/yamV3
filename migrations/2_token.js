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
      "10000000000000000000000",
      YAMImplementation.address,
      "0x"
    );
  } else {
    await deployer.deploy(YAMProxy,
      "YAM",
      "YAM",
      18,
      "10000000000000000000000",
      YAMImplementation.address,
      "0x"
    );
  }
  let yam = await YAMProxy.deployed();
  console.log(YAMProxy.address);
  let multisig = "0x0114ee2238327A1D12c2CeB42921EFe314CBa6E6";
  yam.transfer(multisig, "10000000000000000000000");
}
