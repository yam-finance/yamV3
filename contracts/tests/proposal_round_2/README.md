# Overview

This proposal batch includes a good number of core protocol changes. These have
to be dealt with carefully. We are updating the following aspects of the protocol
- Rebaser
- Governor
- Incentivizer
- Reserves
- YAM Token
- Timelock

Not affected by upcoming changes:
- Migrator

Many people have requested more substantial updates, so I have detailed out all of the changes below. As you will read, these changes are significant and my hope is you see what I have been working on.

## New Rebaser

We will have a new rebaser that does the following:</br>
- Have WETH as the purchase asset
- Use oracle composition of YAM/ETH <> ETH/USDC to achieve YAM/USD TWAP price

Primary modifications occur in the `getTWAP` and `getCurrentTWAP` functions. As
well as storage of a new variable to keep track of ETH/USDC cumulative price.

#### Technical details

There are a few places in the protocol that need to reference the new rebaser. Here are the functions that governance needs to call.
- Action: Set a new rebaser in the reserves contract
  - Target: `reserves`
    - function: `_setRebaser(address)`
    - data: `address(eth_rebaser)`
- Action: Set new rebaser in the YAM token contract
  - Target: `yamV3`
    - function: `_setRebaser(address)`
    - data: `address(eth_rebaser)`  
 </br>
 </br>

Additionally, we want to add sync support for Sushiswap YAM/ETH. We also want to
continue to support YAM/yUSD sync support as there likely will be some zombie liquidity.
Therefore, we should add the following to the proposal:
- Action: Add YAM/ETH sushiswap and YAM/yUSD as sync pairs to new rebaser
  - Target: `eth_rebaser`
    - function: `addSyncPairs(address[],address[])`
    - data: `([0x95b54C8Da12BB23F7A5F6E26C38D04aCC6F81820, 0xb93Cc05334093c6B3b8Bfd29933bb8d5C031caBC],[])`
</br>
</br>

In tandem with this new rebaser, we need to incentivize YAM/ETH liquidity providing. This is included in the following proposal.

## LP Voting

We need LPs to be able to vote in the protocol without having to withdraw their liquidity. To do this, there are a number of required parameters</br>
- Incentivizes YAM/ETH LPing
- Snapshots of LP staking balance
- Snapshots of total LP staking
- Delegation of new LP voting power
- Forced self delegation assigned by governance, implemented via new token logic
- Turn off old incentivizer
- New Governor Alpha that supports multi-address voting power

This is a very significant change that touches almost every part of our protocol.

#### Technical details

##### Updated Token Logic

We require adding a `govOnly` function called `assignSelfDelegate` that takes an address and if it is not currently delegating, delegates to itself. This then will initiate balance snapshots for that address. Snapshots are necessary for anti-manipulation during voting. The Yam token is a proxy, which allows updating the logic. We can add functionality, but new functions will not be visible from etherscan. This `assignSelfDelegate` function will be used on the YAM/ETH uniswap pool to make it start snapshotting its balance. This will increase trade gas costs by roughly `5000` or `10000` gas depending on if one or both addresses are delegating.

- Adds `assignSelfDelegate` to `YAM.sol`

To implement this new logic, the following needs to be included in the governance proposal:
- Action: Update token logic
  - Target: `yamV3`
    - function: `_setImplementation(address,bool,bytes)`
    - data: `[address(new_impl),false,""]`
- Action: Have the ETH/YAM pool self delegate
  - Target: `yamV3`
    - function: `delegateToImplementation(bytes)`
    - data: `abi.encodeWithSignature("assignSelfDelegate(address)", address(0xe2aAb7232a9545F29112f9e6441661fD6eEB0a5d))`  
 </br>
 </br>

##### Updating Incentivizer
We also have to deploy and update the `incentivizer` and tell various contracts in the protocol about this change.

This new `incentivizer` uses YAM/ETH Uniswap LP shares as the staked asset to earn YAM rewards. We will be shutting off the YAM/yUSD pool as well.

This new `incentivizer` snapshots user deposits to keep track of their balance at a particular block. Additionally, the contract snapshots the total LP shares staked. Combined with the updated token logic, this allows us to have a safe way for LP token holders to vote. Voting power is determined by:

1) YAMs held in a user's wallet (+/- any yams delegated) at block height `n - 1`, where n is the block height that a proposal is submitted (no change)</br>
2) Plus, YAMs in the YAM/ETH pool at block height `n - 1` multiplied by their percentage ownership of the total LP shares staked</br>

i.e., There is a scaling factor of 5. Bob has 500 YAMs in his wallet and has staked 100 YAM/ETH LP shares. There are a total of 1000 YAM/ETH LP shares staked. There are 50000 YAMs in the YAM/ETH Uniswap pool. Bob's voting power is `(500 / 5) + (100/1000) * (50000 / 5)`, or:</br> `(YAMsInWallet / scalingFactor) + LPSharesStaked/TotalLPSharesStaked * (YAMSinUniPool / scalingFactor)`. The system is setup to arbitrary allow any number of incentivizer pools, should governance decide to add additional incentivized pools.

There are a few places in the protocol that need to reference the new incentivizer. Here are the functions that governance needs to call.

- Action: Turn off old incentivizer
  - Target: `incentivizer`
    - function: `setBreaker(bool)`
    - data: `true`
- Action: Set new incentivzer
  - Target: `yamV3`
    - function: `_setIncentivizer(address)`
    - data: `address(new_incentivizer)`
- Action: Initialize Incentivizer
  - Target: `new_incentivizer`
    - function: `notifyRewardAmount(uint256)`
    - data: `0` (initial reward is hard coded)
</br>
</br>

##### Updating the Governor
To enable LPs to actually vote, we must update the `admin` over the `timelock`. The `admin` is generally of the form of a `GovernorAlpha` contract. For this update, we have created a `DualGovernorAlpha` that accepts multiple forms of voting power. It works in tandem with the new `incentivizer` to perform the above voting power calculation. It includes the ability to add and remove

- Action: Assign new governor as admin
  - Target: `timelock`
    - function: `setPendingAdmin(address)`
    - data: `address(new_dual_gov_alpha)`
- Action: Add YAM/ETH Incentivizer as a voting power incentivizer
  - Target: `new_dual_gov_alpha`
    - function: `addIncentivizer(address)`
    - data: `address(new_incentivizer)`
</br>
</br>
