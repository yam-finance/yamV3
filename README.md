# 🍠 YAM Protocol 🍠

## The Protocol

Yam is an experimental protocol building upon the most exciting innovations in programmable money and governance. Built by a team of DeFi natives, it seeks to create:

• an elastic supply to seek eventual price stability<br>
• a governable treasury to further support stability<br>
• fully on-chain governance to enable decentralized control and evolution from Day 1<br>
• a fair distribution mechanism that incentivizes key community members to actively take the reins of governance

At its core, YAM is an elastic supply cryptocurrency, which expands and contracts its supply in response to market conditions, initially targeting 1 USD per YAM. This stability mechanism includes one key addition to existing elastic supply models such as Ampleforth: a portion of each supply expansion is used to buy yCurve (a high-yield USD-denominated stablecoin) and add it to the Yam treasury, which is controlled via Yam community governance.

We have built Yam to be a minimally viable monetary experiment, and at launch there will be zero value in the YAM token. After deployment, it is entirely dependent upon YAM holders to determine its value and future development. We have employed a fork of the Compound governance module, which will ensure all updates to the Yam protocol happen entirely on-chain through community voting.

## Audits

None. Contributors have given their best efforts to ensure the security of these contracts, but make no guarantees. It has been spot checked by just a few pairs of eyes. It is a probability - not just a possibility - that there are bugs. That said, minimal changes were made to the staking/distribution contracts that have seen hundreds of millions flow through them via SNX, YFI, and YFI derivatives. The reserve contract is excessively simple as well. We prioritized staked assets' security first and foremost.

The original devs encourage governance to fund a bug bounty/security audit

The token itself is largely based on COMP and Ampleforth which have undergone audits - but we made non-trivial changes.

The rebaser may also have bugs - but has been tested in multiple scenarios. It is restricted to Externally Owned Accounts (EOAs) calling the rebase function for added security. SafeMath is used everywhere.

If you feel uncomfortable with these disclosures, don't stake or hold YAM. If the community votes to fund an audit, or the community is gifted an audit, there is no assumption that the original devs will be around to implement fixes, and is entirely at their discretion.

## The Token

The core YAM token uses yCRV as the reserve currency, which is roughly a $1 peg. Each supply expansion (referred to as an inflating rebase), a portion of tokens is minted and used to build up the treasury. This treasury is then in complete ownership of YAM holders via governance.

## Distribution

Rather than allocating a portion of the supply to the founding team, YAM is being distributed in the spirit of YFI: no premine, no founder shares, no VC interests -- simply equal-opportunity staking distribution to attract a broad and vision-aligned community to steward the future of the protocol and token.

The initial distribution of YAM will be evenly distributed across eight staking pools: WETH, YFI, MKR, LEND, LINK, SNX, COMP, and ETH/AMPL Uniswap v2 LP tokens. These pools were chosen intentionally to reach a broad swath of the overall DeFi community, as well as specific communities with a proven commitment to active governance and an understanding of complex tokenomics.

Following the launch of the initial distribution pools, a second distribution wave will be incentivized through a YAM/yCRV Uniswap pool. This pool will allow Uniswap's TWAP-based oracle to provide necessary input as the basis for rebase calculations, as well as provide liquidity for the rebase to purchase yCurve for the treasury.

## Rebases

Rebases are controlled by an external contract called the Rebaser. This is comparable to Ampleforth's `monetaryPolicy` contract. It dictates how large the rebase is and what happens on the rebase. The YAM token just changes the supply based on what this contract provides it.

There are a requirements before rebases are active:<br>
• Liquid YAM/yCRV market<br>
• `init_twap()`<br>
• `activate_rebasing()`<br>

Following the launch of the second pool, rebasing can begin its activation phase. This begins with `init_twap()` on the rebaser contract. Anyone can call this at anytime once there is a YAM/yCRV Uniswap V2 market. The oracle is designed to be 12 hours between checkpoints. Given that, 12 hours after `init_twap()` is called, anyone can call `activate_rebasing()`. This turns rebasing on, permanently. Now anyone can call `rebase()` when `inRebaseWindow() == true;`.

In a rebase, the order of operations are:<br>
• ensure in rebase window<br>
• calculate how far off-price is from the peg<br>
• dampen the rebase by the rebaseLag<br>
• if positive calculate protocol mint amount<br>
• change scaling factor, (in/de)flating the supply<br>
• sync uniswap, mint, sell to uniswap, transfer excess YAM and bought yCRV to reserves<br>
• call any extra functions governance adds in the future (i.e. Balancer gulps)<br>

## Governance

Governance is entirely dictated by YAM holders from the start. Upon deployment, ownership of all YAM protocol contracts was relinquished to the timelocked Governance contract or removed entirely. At the very least, this can be seen as a reference implementation for a truly decentralized protocol.

# Development

## Building

This repo uses truffle and `dapptest` for testing. Most of the updated tests were done using dapptest, while deployment will be handled by truffle. Some tests weren't transfered over from v1, particularly around governance.

Then, to build the contracts for deployment run:

```
$ truffle compile
```

To run tests, install Nix and dapptools:

```
$ curl -L https://nixos.org/nix/install > nix.sh
$ nix-env -iA dapp seth hevm -f https://github.com/dapphub/dapptools/tarball/master -v
```

Running tests:

```
$ export ETH_RPC_URL=http://localhost:8545 # mainnet node
$ ./scripts/dapp-test.sh [test_name]
```

### Attributions

Much of this codebase is modified from existing works, including:

[Compound](https://compound.finance) - Jumping off point for token code and governance

[Ampleforth](https://ampleforth.org) - Initial rebasing mechanism, modified to better suit the YAM protocol

[Synthetix](https://synthetix.io) - Rewards staking contract

[YEarn](https://yearn.finance)/[YFI](https://ygov.finance) - Initial fair distribution implementation
