# Overview
This is a checklist for updating various parts of the protocol.
</br>

----
## Rebaser
- [ ] Added sync pairs: `addSyncPairs` - Pre-gov
- [ ] Set Pending Governance: `_setPendingGov` - Pre-gov
- [ ] Updated reserves reference: `_setRebaser`
- [ ] Updated Token reference: `_setRebaser`
- [ ] Accept Governance: `_acceptGov`
- [ ] Rebase Lag, Mint %, Deviation, Interval, Slippage factor match current implementation; `On deployment`
</br>

### References
- Reserves, `rebaser`
- Token, `rebaser`
</br>

### Checks
- `getUniSyncPairs == expected_syncUniPairs`
- `getBalGulpPairs == expected_syncBalPairs`
- `targetRate == expected_targetRate`
- `rebaseMintPerc == expected_rebaseMintPerc`
- `deviationThreshold == expected_dt`
- `minRebaseTimeInterval == expected_mrti`
- `yamAddress == yam`
- `reserveToken == expected_reserveToken`
- `reservesContract == expected_reservesContract`
- `trade_pair == expected_tp`
- `eth_usdc_pair == expected_eth_usdc_pair`
- `public_goods == expected_public_goods`
- `public_goods_perc == expected_public_goods_perc`
- `maxScalingFactor == expected_msf`
- `gov == timelock`
- `reserves.rebaser == self`
- `token.rebaser == self`

----
## Reserves
- [ ] Set Rebaser:    `_setRebaser` - Pre-gov
- [ ] Set Pending Governance: `_setPendingGov` - Pre-gov
- [ ] Migrate Reserves:  `migrateReserves`
- [ ] Update Rebaser:    `setReserveContract`
- [ ] Accept Governance: `_acceptGov`
</br>

### References
- Rebaser, `reservesContract`
</br>

### Checks
- `token_balances == expected_token_balances`
- `gov == timelock`
- `rebaser.reservesContract == self`
----
## LP rewards
- [ ] Min Block Before Voting: `setMinBlockBeforeVoting` - Pre-gov
- [ ] Set rewardDistribution: `setRewardDistribution` - Pre-gov
- [ ] Set Governance: `transferOwnership` - Pre-gov
- [ ] Update Incentivizer: `_setIncentivizer`
- [ ] Turn off old incentivizer: `setBreaker`
- [ ] Notify Reward: `notifyRewardAmount`
- [ ] Assign Self Delegate for incentivized pool: `assignSelfDelegate`
- [ ] Add voting: `addIncentivizer`
- [ ] Init reward correct: `On Deployment`
- [ ] Start time correct: `On Deployment`

### References
- Token, `incentivizer`
- Governor, `incentivizers`
</br>

### Checks
- `token.incentivizer == expected_incentivizer`
- `gov.incentivizers == expected_incentivizers`
- `minBlockBeforeVoting == expected_minBlockBeforeVoting`
- `owner == timelock`
- `rewardDistribution == timelock`
- `oldIncentivizer.breaker == true`
- `starttime == expected_starttime`
- `initreward == expected_initreward`
- `inc.slp.delegate == inc.slp`
----
## Implementation
- [ ] Set Implementation: `_setImplementation`
</br>

### References
- Token, `implementation`
</br>

### Checks
- `implementation == expected_implementation`

----
## Governor
- [ ] Initialize with voting incentivizers: `On deployment`
- [ ] Set Pending Admin of Timelock: `setPendingAdmin`
- [ ] Accept Pending Admin: `__acceptAdmin` (from guardian)
</br>

### References
- Timelock, `admin`
</br>

### Checks
- `timelock == expected_timelock`
- `yam == expected_yam`
- `guardian == expected_guardian`
- `proposalCount == 0`
- `incentivizers == expected_incentivizers`
- `timelock_admin == self`
----
## OTC Purchase
- [ ] Setup sale or purchase: `setup_sale`, `setup_purchase`
- [ ] Whitelist withdraw: `whitelistWithdrawals`
</br>

### References
</br>

### Checks
- `sell_token.allowance(reserve, otc) >= sell_amount/purchase_amount`
- `uniswap_pair1 == expected_uni1`
- `uniswap_pair2 == expected_uni2`
- `trader == expected_trader`
- `isSale == expected_isSale`
- `twap_counter == 0`
- `wrong_side_amount == 0`
- `complete == false`
----
