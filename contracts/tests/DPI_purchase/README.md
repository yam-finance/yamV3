# Overview

This contract facilitates a trustless OTC deal between two parties that have approved this contract to spend their respective tokens.

<strong>tl;dr:

Trader and purchaser approve OTC contract to spend their tokens, trader executes the trade ensuring their requirements are met. Purchaser relies on a TWAP oracle to ensure their requirements are met.</strong>

There are two parties, the reserve (purchaser) and the trader (OTC desk). This contract's main use is for DAOs that do not have admin privileges and must go through a governance process to execute the trade.

## Flow
The purchaser configures the trade by defining:
 - The approved counterparty
 - The token they are selling
 - The token they are buying
 - The address where the sale tokens are coming from
 - TWAP period (more on that later)
 - % acceptable off Uniswap TWAP
 - If it is a sale or a purchase
   - if sale:
     - Number of tokens to sell
   - if purchase:
     - Number of tokens to buy

The purchaser approves the OTC contract to spend their sale tokens (if it is a purchase trade, they will approve more than expected trade price).

Upon configuration, a Uniswap TWAP (time weight average price) oracle is initiated. This oracle will be used as a bounds check at time of purchase.

Once the TWAP is initiated, and both parties have approved the contract to spend their respective tokens, the trade can take place at anytime within an hour of the last TWAP update.

## The Trade

The trader should communicate with a representative of the DAO to discuss execution price prior to execution. There are 2 reasons for this:
 1. Allows representative to ensure the trade will be successful (and meet bounds checks)
 2. Grows trust between two parties for future business so that neither are blindsided (while the contract ensures no one is screwed over, the DAO is in a slight disadvantage for ensuring they are getting a fair price)

If:
 - The transaction sender is the approved Trader
 - TWAP has been updated within the last hour
 - The trade hasnt already been completed

the trader can initiate the trade. They pass two parameters in:
 1. Amount of tokens they are transferring to the purchaser
 2. Amount of tokens they expect (at minimum) from the purchaser

If the purchaser is providing equal to or more than the expected number of tokens (as defined in the input), a check on behalf of the purchaser is performed by consulting the TWAP oracle. Assuming both pass, tokens are transferred to their respective parties.

Finally, the trade is marked as complete.

## Example

YAM configures a `sale` trade as the following:
 - trader: `address(GRAPEFRUIT)`
 - sale_token: `address(yUSD)`
 - purchase_token: `address(DPI)`
 - reserve: `address(YAM_RESERVE)`
 - TWAP Period: `2 hours`
 - Acceptable off TWAP %: `1.5%`
 - sale_tokens: `215518 (yUSD)`

YAM approves the OTC contract to spend 215518 yUSD ($250k).

After waiting the TWAP period (2 hours) after configuring the trade, someone (anyone) updates the twap price (reads the price directly from uniswap, but may hop from yUSD/ETH -> ETH/DPI to obtain yUSD/DPI). For this example say the current TWAP is 71 yUSD:DPI.

Within the next hour, Grapefruit quotes YAM DAO with a purchase price of 72 yUSD:DPI, and approves the OTC contract to spend 2993 DPI (215518 / 72).

Grapefruit executes the trade with the following parameters:
`trade(2993, 215518)` which corresponds to trade 2993 DPI for at least 215518 yUSD.

The contract ensures that the `sale_tokens` >= 215518 as well as ensuring that (215518 / 2993) is less than 1.5% away from 71, the current TWAP. Tokens are then transferred to their respective parties.
