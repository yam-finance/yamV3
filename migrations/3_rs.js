// ============ Contracts ============

// Token
// deployed first
const YAMImplementation = artifacts.require("YAMDelegate");
const YAMProxy = artifacts.require("YAMDelegator");

// Rs
// deployed second
const YAMReserves = artifacts.require("YAMReserves");
const YAMRebaser = artifacts.require("YAMRebaser");
const Migrator = artifacts.require("Migrator");

// ============ Main Migration ============

const migration = async (deployer, network, accounts) => {
  await Promise.all([
    deployRs(deployer, network),
  ]);
};

module.exports = migration;

// ============ Deploy Functions ============


async function deployRs(deployer, network) {
  let reserveToken = "0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c"; //yyCRV
  let uniswap_factory = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";
  let grants = "0xde21F729137C5Af1b01d73aF1dC21eFfa2B8a0d6";
  let perc = (10**16).toString();
  await deployer.deploy(YAMReserves, reserveToken, YAMProxy.address);
  await deployer.deploy(YAMRebaser,
      YAMProxy.address,
      reserveToken,
      uniswap_factory,
      YAMReserves.address,
      grants,
      perc
  );
  await deployer.deploy(Migrator);

  let migrator = await Migrator.deployed();

  let rebase = new web3.eth.Contract(YAMRebaser.abi, YAMRebaser.address);

  let pair = await rebase.methods.uniswap_pair().call();
  console.log(pair)
  let yam = await YAMProxy.deployed();
  await yam._setRebaser(YAMRebaser.address);
  await yam._setMigrator(Migrator.address);
  let reserves = await YAMReserves.deployed();
  migrator.setV3Address(YAMProxy.address);
  await reserves._setRebaser(YAMRebaser.address)
}
