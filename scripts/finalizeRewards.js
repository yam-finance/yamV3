var Web3 = require('web3');
var assert = require('assert');
const HDWalletProvider = require("@truffle/hdwallet-provider");
require('dotenv-flow').config();
let p = new HDWalletProvider(
  [process.env.DEPLOYER_PRIVATE_KEY],
  //'https://mainnet.infura.io/v3/731a2b3d28e445b7ac56f23507614fea',//'https://fee7372b6e224441b747bf1fde15b2bd.eth.rpc.rivet.cloud',
  0,
  1,
);

var gp = Number(process.env.GAS_PRICE);
var web3 = new Web3(p);
let migrator = new web3.eth.Contract([{"inputs": [], "payable": false, "stateMutability": "nonpayable", "type": "constructor"}, {"anonymous": false, "inputs": [{"indexed": true, "internalType": "address", "name": "previousOwner", "type": "address"}, {"indexed": true, "internalType": "address", "name": "newOwner", "type": "address"}], "name": "OwnershipTransferred", "type": "event"}, {"constant": true, "inputs": [], "name": "BASE", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": true, "inputs": [{"internalType": "address", "name": "", "type": "address"}], "name": "claimed", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": true, "inputs": [], "name": "delegatorRewardsSet", "outputs": [{"internalType": "bool", "name": "", "type": "bool"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": true, "inputs": [], "name": "delegatorVestingDuration", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": true, "inputs": [{"internalType": "address", "name": "", "type": "address"}], "name": "delegator_claimed", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": true, "inputs": [{"internalType": "address", "name": "", "type": "address"}], "name": "delegator_vesting", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": true, "inputs": [], "name": "owner", "outputs": [{"internalType": "address", "name": "", "type": "address"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": false, "inputs": [], "name": "renounceOwnership", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function"}, {"constant": true, "inputs": [], "name": "startTime", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": true, "inputs": [], "name": "token_initialized", "outputs": [{"internalType": "bool", "name": "", "type": "bool"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": false, "inputs": [{"internalType": "address", "name": "newOwner", "type": "address"}], "name": "transferOwnership", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function"}, {"constant": true, "inputs": [{"internalType": "address", "name": "", "type": "address"}], "name": "vesting", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": true, "inputs": [], "name": "vestingDuration", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": true, "inputs": [], "name": "yamV2", "outputs": [{"internalType": "address", "name": "", "type": "address"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": true, "inputs": [], "name": "yamV3", "outputs": [{"internalType": "address", "name": "", "type": "address"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": false, "inputs": [{"internalType": "address", "name": "yamV3_", "type": "address"}], "name": "setV3Address", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function"}, {"constant": false, "inputs": [], "name": "delegatorRewardsDone", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function"}, {"constant": true, "inputs": [{"internalType": "address", "name": "who", "type": "address"}], "name": "vested", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "payable": false, "stateMutability": "view", "type": "function"}, {"constant": false, "inputs": [], "name": "migrate", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function"}, {"constant": false, "inputs": [], "name": "claimVested", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function"}, {"constant": false, "inputs": [{"internalType": "address[]", "name": "delegators", "type": "address[]"}, {"internalType": "uint256[]", "name": "amounts", "type": "uint256[]"}, {"internalType": "bool", "name": "under27", "type": "bool"}], "name": "addDelegatorReward", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function"}, {"constant": false, "inputs": [{"internalType": "address", "name": "token", "type": "address"}, {"internalType": "address", "name": "to", "type": "address"}, {"internalType": "uint256", "name": "amount", "type": "uint256"}], "name": "rescueTokens", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function"}], "0x72CFEd9293cbFB2bfC7515c413048c697C6c811C");

var fs = require('fs');

let base = web3.utils.toBN(10).pow(web3.utils.toBN(24));
let twentySeven = web3.utils.toBN(27).mul(base);

async function a() {
  fs.readFile('../delegators.json', 'utf8', function(err, contents) {
    var delegators = JSON.parse(contents);
    delegators = delegators.sort(function(a, b) {
      return web3.utils.toBN(b["balanceOfUnderlying"]).cmp(web3.utils.toBN(a["balanceOfUnderlying"]))
    })
    console.log(web3.utils.toBN(delegators[0]["balanceOfUnderlying"]), twentySeven, delegators.slice(delegators.length - 35,)[0])
    delegatorRewards().then(e => console.log(e))
    return;
  });
  return;
}

async function delegatorRewards() {
  let accounts = await web3.eth.getAccounts();
  let vesting = await migrator.methods.delegator_vesting("0xa4E40b3d3e1B04043C4Cb89810e055A78CAF272b").call()
  console.log(vesting)
  assert(vesting == "27000000000000000000000000");
  vesting = await migrator.methods.delegator_vesting("0x82976035255dE68a31AdD874AcdaaAC78a3E6516").call()
  console.log(vesting)
  assert(vesting == "27000000000000000000000000");
  vesting = await migrator.methods.delegator_vesting("0x65C084B69b7F21aCEFe2c68AA25C67Efd2E10160").call()
  assert(vesting == "7783095872406225027581378515");
  // await migrator.methods.delegatorRewardsDone().send({from: accounts[0], gas: 100000, gasPrice: gp});
  await migrator.methods.transferOwnership("0x8b4f1616751117C38a0f84F9A146cca191ea3EC5").send({from: accounts[0], gas: 100000, gasPrice: gp});
  return "done"
}

a()
