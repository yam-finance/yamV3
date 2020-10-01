var Web3 = require('web3');
var assert = require('assert');
const HDWalletProvider = require("@truffle/hdwallet-provider");
require('dotenv-flow').config();
let p = new HDWalletProvider(
  [process.env.DEPLOYER_PRIVATE_KEY],
  //'https://fee7372b6e224441b747bf1fde15b2bd.eth.rpc.rivet.cloud',
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
    console.log(web3.utils.toBN(delegators[0]["balanceOfUnderlying"]), twentySeven, delegators.slice(1478,)[0])
    delegatorRewards(delegators).then(e => console.log(e))
    return;
  });
  return;
}

async function delegatorRewards(delegators) {
  let accounts = await web3.eth.getAccounts();
  let dels = []
  let amts = []
  let under = false;
  let a;
  for (let i = 0; i < delegators.length; i++) {

      if (web3.utils.toBN(delegators[i]["balanceOfUnderlying"]).lt(twentySeven)) {
        let vesting = web3.utils.toBN(await migrator.methods.delegator_vesting(delegators[i]["address"]).call());
        console.log(vesting.toString() == delegators[i]["balanceOfUnderlying"], vesting.toString(), delegators[i]["balanceOfUnderlying"]);
        if (vesting.eq(twentySeven)) {
          continue;
        } else {
          dels.push(delegators[i]["address"]);
          amts.push(0);
        }
      } else {
        let vesting = web3.utils.toBN(await migrator.methods.delegator_vesting(delegators[i]["address"]).call());
        console.log(vesting.toString() == delegators[i]["balanceOfUnderlying"], vesting.toString(), delegators[i]["balanceOfUnderlying"]);
        if (vesting.eq(web3.utils.toBN(delegators[i]["balanceOfUnderlying"]))) {
          continue;
        } else {
          dels.push(delegators[i]["address"]);
          amts.push(delegators[i]["balanceOfUnderlying"]);
        }
      }
  }
  console.log(dels)
  console.log(amts)
}

a()
