// ============ Contracts ============


// Protocol
// deployed second
const YAMImplementation = artifacts.require("YAMDelegate");
const YAMProxy = artifacts.require("YAMDelegator");

// deployed third
const YAMReserves = artifacts.require("YAMReserves");
const YAMRebaser = artifacts.require("YAMRebaser");

const Gov = artifacts.require("GovernorAlpha");
const Timelock = artifacts.require("Timelock");

// deployed fourth
const YAM_ETHPool = artifacts.require("YAMETHPool");
const YAM_uAMPLPool = artifacts.require("YAMAMPLPool");
const YAM_YFIPool = artifacts.require("YAMYFIPool");
const YAM_LINKPool = artifacts.require("YAMLINKPool");
const YAM_MKRPool = artifacts.require("YAMMKRPool");
const YAM_LENDPool = artifacts.require("YAMLENDPool");
const YAM_COMPPool = artifacts.require("YAMCOMPPool");
const YAM_SNXPool = artifacts.require("YAMSNXPool");


// deployed fifth
const YAMIncentivizer = artifacts.require("YAMIncentivizer");

// ============ Main Migration ============

const migration = async (deployer, network, accounts) => {
  await Promise.all([
    // deployTestContracts(deployer, network),
    deployDistribution(deployer, network, accounts),
    // deploySecondLayer(deployer, network)
  ]);
}

module.exports = migration;

// ============ Deploy Functions ============


async function deployDistribution(deployer, network, accounts) {
  console.log(network)
  let yam = await YAMProxy.deployed();
  let yReserves = await YAMReserves.deployed()
  let yRebaser = await YAMRebaser.deployed()
  let tl = await Timelock.deployed();
  let gov = await Gov.deployed();
  if (network != "test") {
    await deployer.deploy(YAMIncentivizer);

    let ycrv_pool = new web3.eth.Contract(YAMIncentivizer.abi, YAMIncentivizer.address);

    console.log("setting distributor");
    await Promise.all([
        ycrv_pool.methods.setRewardDistribution(accounts[0]).send({from: accounts[0], gas: 100000}),
      ]);

    let two_fifty = web3.utils.toBN(10**3).mul(web3.utils.toBN(10**18)).mul(web3.utils.toBN(250));
    let one_five = two_fifty.mul(web3.utils.toBN(6));

    console.log("transfering and notifying");
    console.log("eth");
    await Promise.all([
      yam._setIncentivizer(YAMIncentivizer.address),
    ]);

    await Promise.all([
      // incentives is a minter and prepopulates itself.
      ycrv_pool.methods.notifyRewardAmount("0").send({from: accounts[0], gas: 500000}),
    ]);

    await Promise.all([
      ycrv_pool.methods.setRewardDistribution(Timelock.address).send({from: accounts[0], gas: 100000}),
    ]);
    await Promise.all([
      ycrv_pool.methods.transferOwnership(Timelock.address).send({from: accounts[0], gas: 100000}),
    ]);
  }

  await Promise.all([
    yam._setPendingGov(Timelock.address),
    yReserves._setPendingGov(Timelock.address),
    yRebaser._setPendingGov(Timelock.address),
  ]);

  await Promise.all([
      tl.executeTransaction(
        YAMProxy.address,
        0,
        "_acceptGov()",
        "0x",
        0
      ),

      tl.executeTransaction(
        YAMReserves.address,
        0,
        "_acceptGov()",
        "0x",
        0
      ),

      tl.executeTransaction(
        YAMRebaser.address,
        0,
        "_acceptGov()",
        "0x",
        0
      ),
  ]);
  await tl.setPendingAdmin(Gov.address);
  await gov.__acceptAdmin();
  await gov.__abdicate();
}
