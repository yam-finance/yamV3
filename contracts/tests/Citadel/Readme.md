# Citadel lending
Citadel Lending uses _segregated risk pools_ (see below) & _TWAP_ (time-weighted average price) to enable permissionless lending and borrowing. There is no governance over a pool, it is created and exists in that initiated state in perpetuity.

There is a factory contract similar to that of Uniswap's that facilitates creation and initialization of pools, as well as keeping track of pools for an asset.


_Segregated risk pools_ means risks are localized. Compound, for example, cannot add extremely risky assets as it puts the entire system at risk. In Citadel, the protocol does nothing to protect users from risky assets, but it limits the fallout to pools that have such an asset if that asset blows up (i.e. price plummets to 1% of its usual value in a matter of minutes, say from a rug pull).

Many parameters are set in stone at creation of the pool, such as:
1. Collateralization Ratio & Margin Premiums (similar to Compound's collateral factor)
2. Liquidation Premium
3. Assets in the pool
4. Oracle parameters & denominating token (you can set an arbitrary token to be the benchmark for collateralization calculation, i.e. USDC, WETH, etc.)

Pool creation should generally be left to more advanced users.

There are 3 main functions a user can take:
- Deposit
  - If there are borrowers, the user starts to earn interest immediately by enabling borrows to borrow your asset
- Withdraw
  - You can withdraw any amount of any of the assets regardless of your balance, so long as your account remains collateralized.
  - If the withdrawal amount exceeds your balance, a borrow is  opened
  - If the price of the borrowed asset moves up, your position could become undercollateralized. At which point, your account can be liquidated by allowing another user to effectively buy your collateral at a discount.
- Trade
  - Citadel enables users to take leverage on any asset in the pool by borrowing a secondary asset and selling it for another. How much leverage is possible is determined by the specific pool's collateralization ratio
  - This trading is performed via Uniswap or Sushiswap, but is not inherently restricted to those exchanges. Trades, in the backend, use flashloans and therefore can interact with any exchange.


For more sophisticated users, you can participate in (but there is no UI to support such activities):
- Flashloans
  - Currently, Citadel offers the most gas efficient flashloans in roughly the 140k gas range.
  - Trades use these in the backend
- Liquidations
  - If an account becomes undercollateralized, it is the responsibility of the pool's participants/profit-seekers to pay back the borrowed assets in exchange for a discount on a secondary asset in the pool. The discount is determined at the start of the pool
