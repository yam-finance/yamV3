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
  let yam = await YAMProxy.deployed();
  let yReserves = await YAMReserves.deployed()
  let yRebaser = await YAMRebaser.deployed()
  let tl = await Timelock.deployed();
  let gov = await Gov.deployed();
  await deployer.deploy(YAMIncentivizer);

  let yycrv_pool = await YAMIncentivizer.deployed(); //
  let yycrv_poolw3 = new web3.eth.Contract(YAMIncentivizer.abi, YAMIncentivizer.address);

  console.log("setting distributor");
  await Promise.all([
      yycrv_pool.setRewardDistribution("0x683A78bA1f6b25E29fbBC9Cd1BFA29A51520De84") //.send({from: accounts[0], gas: 100000}),
    ]);

  let two_fifty = web3.utils.toBN(10**3).mul(web3.utils.toBN(10**18)).mul(web3.utils.toBN(250));
  let one_five = two_fifty.mul(web3.utils.toBN(6));

  console.log("transfering and notifying");
  console.log("setting incentivizer");
  await Promise.all([
    yam._setIncentivizer(YAMIncentivizer.address),
  ]);

  console.log("notifying reward");
  await yycrv_poolw3.methods.notifyRewardAmount(0).send({from: "0x683A78bA1f6b25E29fbBC9Cd1BFA29A51520De84", gas: 500000});

  console.log("set reward distribution");
  await Promise.all([
    yycrv_pool.setRewardDistribution(Timelock.address) //.send({from: accounts[0], gas: 100000}),
  ]);
  console.log("transfering ownership")
  await Promise.all([
    yycrv_pool.transferOwnership(Timelock.address) //.send({from: accounts[0], gas: 100000}),
  ]);

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
