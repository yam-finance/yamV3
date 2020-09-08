// SPDX-License-Identifier: MIT
pragma solidity 0.5.15;

import "../lib/SafeERC20.sol";
import "../lib/Context.sol";
import "../lib/SafeMath.sol";
import "../lib/Ownable.sol";

interface YAMv2 {
  function balanceOf(address owner) external view returns (uint256);
}

interface YAMv3 {
  function mint(address owner, uint256 amount) external;
}


/**
 * @title YAMv2 Token
 * @dev YAMv2 Mintable Token with migration from legacy contract. Used to signal
 *      for protocol changes in v3.
 */
contract Migrator is Context, Ownable {

    using SafeMath for uint256;

    address public constant yamV2 = address(0xAba8cAc6866B83Ae4eec97DD07ED254282f6aD8A);

    address public yamV3;

    bool public token_initialized;

    bool public delegatorRewardsSet;

    uint256 public constant vestingDuration = 30 days;

    uint256 public constant delegatorVestingDuration = 90 days;

    uint256 public constant startTime = 1600560000; // TBD! Sunday, September 20, 2020 12:00:00 AM

    uint256 public constant BASE = 10**18;

    mapping(address => uint256) public delegator_vesting;

    mapping(address => uint256) public delegator_claimed;

    mapping(address => uint256) public vesting;

    mapping(address => uint256) public claimed;

    constructor () public {
    }



    /**
     * @dev Sets yamV2 token address
     *
     */
    function setV3Address(address yamV3_) public onlyOwner {
        require(!token_initialized, "already set");
        token_initialized = true;
        yamV3 = yamV3_;
    }

    // Tells contract delegator rewards setting is done
    function delegatorRewardsDone() public onlyOwner {
        delegatorRewardsSet = true;
    }


    function vested(address who) public view returns (uint256) {
      // completion percentage of vesting
      uint256 vestedPerc = now.sub(startTime).mul(BASE).div(vestingDuration);

      uint256 delegatorVestedPerc = now.sub(startTime).mul(BASE).div(delegatorVestingDuration);

      if (vestedPerc > BASE) {
          vestedPerc = BASE;
      }
      if (delegatorVestedPerc > BASE) {
          delegatorVestedPerc = BASE;
      }

      // add to total vesting
      uint256 totalVesting = vesting[who];

      // get redeemable total vested by checking how much time has passed
      uint256 totalVestingRedeemable = totalVesting.mul(vestedPerc).div(BASE);

      uint256 totalVestingDelegator = delegator_vesting[who].mul(delegatorVestedPerc).div(BASE);

      // get already claimed vested rewards
      uint256 alreadyClaimed = claimed[who].add(delegator_claimed[who]);

      // get current redeemable
      return totalVestingRedeemable.add(totalVestingDelegator).sub(alreadyClaimed);
    }


    modifier started() {
        require(block.timestamp >= startTime, "!started");
        require(token_initialized, "!initialized");
        require(delegatorRewardsSet, "!delegatorRewards");
        _;
    }

    /**
     * @dev Migrate a users' entire balance
     *
     * One way function. YAMv2 tokens are BURNED. 1/2 YAMv3 tokens are minted instantly, other half vests over 1 month.
     */
    function migrate()
        external
        started
    {
        // completion percentage of vesting
        uint256 vestedPerc = now.sub(startTime).mul(BASE).div(vestingDuration);

        // completion percentage of delegator vesting
        uint256 delegatorVestedPerc = now.sub(startTime).mul(BASE).div(delegatorVestingDuration);

        if (vestedPerc > BASE) {
            vestedPerc = BASE;
        }
        if (delegatorVestedPerc > BASE) {
            delegatorVestedPerc = BASE;
        }

        // gets the yamValue for a user.
        uint256 yamValue = YAMv2(yamV2).balanceOf(_msgSender());

        // half is instant redeemable
        uint256 halfRedeemable = yamValue / 2;

        uint256 mintAmount;

        // scope
        {
            // add to total vesting
            uint256 totalVesting = vesting[_msgSender()].add(halfRedeemable);

            // update vesting
            vesting[_msgSender()] = totalVesting;

            // get redeemable total vested by checking how much time has passed
            uint256 totalVestingRedeemable = totalVesting.mul(vestedPerc).div(BASE);

            uint256 totalVestingDelegator = delegator_vesting[_msgSender()].mul(delegatorVestedPerc).div(BASE);

            // get already claimed
            uint256 alreadyClaimed = claimed[_msgSender()];

            // get already claimed delegator
            uint256 alreadyClaimedDelegator = delegator_claimed[_msgSender()];

            // get current redeemable
            uint256 currVested = totalVestingRedeemable.sub(alreadyClaimed);

            // get current redeemable delegator
            uint256 currVestedDelegator = totalVestingDelegator.sub(alreadyClaimedDelegator);

            // add instant redeemable to current redeemable to get mintAmount
            mintAmount = halfRedeemable.add(currVested).add(currVestedDelegator);

            // update claimed
            claimed[_msgSender()] = claimed[_msgSender()].add(currVested);

            // update delegator rewards claimed
            delegator_claimed[_msgSender()] = delegator_claimed[_msgSender()].add(currVestedDelegator);
        }


        // BURN YAMv2 - UNRECOVERABLE.
        SafeERC20.safeTransferFrom(
            IERC20(yamV2),
            _msgSender(),
            address(0x000000000000000000000000000000000000dEaD),
            yamValue
        );

        // mint, this is in raw internalDecimals. Handled by updated _mint function
        YAMv3(yamV3).mint(_msgSender(), mintAmount);
    }


    function claimVested()
        external
        started
    {
        // completion percentage of vesting
        uint256 vestedPerc = now.sub(startTime).mul(BASE).div(vestingDuration);

        // completion percentage of delegator vesting
        uint256 delegatorVestedPerc = now.sub(startTime).mul(BASE).div(delegatorVestingDuration);

        if (vestedPerc > BASE) {
            vestedPerc = BASE;
        }
        if (delegatorVestedPerc > BASE) {
          delegatorVestedPerc = BASE;
        }

        // add to total vesting
        uint256 totalVesting = vesting[_msgSender()];

        // get redeemable total vested by checking how much time has passed
        uint256 totalVestingRedeemable = totalVesting.mul(vestedPerc).div(BASE);

        uint256 totalVestingDelegator = delegator_vesting[_msgSender()].mul(delegatorVestedPerc).div(BASE);

        // get already claimed vested rewards
        uint256 alreadyClaimed = claimed[_msgSender()];

        // get already claimed delegator
        uint256 alreadyClaimedDelegator = delegator_claimed[_msgSender()];

        // get current redeemable
        uint256 currVested = totalVestingRedeemable.sub(alreadyClaimed);

        // get current redeemable delegator
        uint256 currVestedDelegator = totalVestingDelegator.sub(alreadyClaimedDelegator);

        // update claimed
        claimed[_msgSender()] = claimed[_msgSender()].add(currVested);

        // update delegator rewards claimed
        delegator_claimed[_msgSender()] = delegator_claimed[_msgSender()].add(currVestedDelegator);

        // mint, this is in raw internalDecimals. Handled by updated _mint function
        YAMv3(yamV3).mint(_msgSender(), currVested.add(currVestedDelegator));
    }


    // this is a gas intensive airdrop of sorts
    function addDelegatorReward(
        address[] calldata delegators,
        uint256[] calldata amounts,
        bool under27 // indicates this batch is for those who delegated under 27 yams
    )
        external
        onlyOwner
    {
        require(!delegatorRewardsSet, "set");
        require(delegators.length == amounts.length, "!len");
        if (!under27) {
            for (uint256 i = 0; i < delegators.length; i++) {
                delegator_vesting[delegators[i]] = amounts[i]; // must be on order of 1e24;
            }
        } else {
            for (uint256 i = 0; i < delegators.length; i++) {
                delegator_vesting[delegators[i]] = 27 * 10**24; // flat distribution;
            }
        }
    }

    // if people are dumb and send tokens here, give governance ability to save them.
    function rescueTokens(
        address token,
        address to,
        uint256 amount
    )
        external
        onlyOwner
    {
        // transfer to
        SafeERC20.safeTransfer(IERC20(token), to, amount);
    }
}
