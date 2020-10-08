// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import { YAMIncentivizerWithVoting } from "./YAMIncentivesWithVoting.sol";
import { DualGovernorAlpha } from "./YAMGovernorAlphaWithLps.sol";

contract Gov3 is YAMv3Test {


    YAMIncentivizerWithVoting voting_inc;
    DualGovernorAlpha gov3;
    YAMDelegate new_impl;
    address eth_yam_lp = address(0xe2aAb7232a9545F29112f9e6441661fD6eEB0a5d);
    function setUp() public {
        setUpCore();
        voting_inc = new YAMIncentivizerWithVoting();
        address[] memory incentivizers = new address[](1);
        incentivizers[0] = address(voting_inc);
        gov3 = new DualGovernorAlpha(address(timelock), address(yamV3), incentivizers);
        new_impl = new YAMDelegate();
    }

    //
    // TESTS
    //
    function test_LPVotingPower() public {
        // test includes:
        // -- increase lp token balance
        // -- own existing incentivizer
        // -- set breaker to turn existing incentivizer off
        // -- get yam governance
        // -- update implementation
        // -- set new incentivizer
        // -- increase approval & stake
        // -- check voting power
        // -- add another staker, that is 1% of staking pool
        // -- check voting power

        // -- force verbose output
        assertTrue(false);

        // -- increase balance

        yamhelper.write_balanceOf(eth_yam_lp, me, 990*10**18); // we inflate away most other holders to simulate large number of stakers

        // -- own existing incentivizer
        helper.write_flat(address(incentivizer), "owner()", me);
        assertEq(incentivizer.owner(), me);

        // -- set breaker to turn it off
        incentivizer.setBreaker(true);

        // -- get yam governance
        yamhelper.becomeGovernor(yamV3, me);
        yamV3._acceptGov();

        // -- update implementation
        yamV3._setImplementation(address(new_impl), false, "");
        address yyCRVPool = pairFor(uniFact, address(yamV3), yyCRV);
        yamV3.delegateToImplementation(abi.encodeWithSignature("assignSelfDelegate(address)", eth_yam_lp));
        assertEq(yamV3.delegates(eth_yam_lp), eth_yam_lp);

        // -- set new incentivizer
        yamV3._setIncentivizer(address(voting_inc));
        voting_inc.setRewardDistribution(me);
        assertEq(voting_inc.rewardDistribution(), me);
        voting_inc.notifyRewardAmount(0);

        // -- increase approval & stake
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 poolPower = yamV3.getCurrentVotes(eth_yam_lp);
        uint256 mePower = yamV3.getCurrentVotes(me);
        yamhelper.bing(); // increase block number
        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);

        // -- check voting power
        assertEq(voting_inc.getPriorVotes(me, block.number - 1), poolPower);
        assertEq(gov3.getPriorVotes(me, block.number - 1), poolPower + mePower);
        // -- add another staker, that is 1% of staking pool
        user.doStake(yamhelper, address(voting_inc), 10*10**18);
        yamhelper.bing();

        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);
        assertEq(voting_inc.getPriorLPStake(address(user), block.number - 1), 10*10**18);

        // -- check voting power
        assertEq(voting_inc.getPriorVotes(me, block.number - 1), poolPower * 99 / 100);
        assertEq(voting_inc.getPriorVotes(address(user), block.number - 1), poolPower / 100);
    }

    function test_LPVotingGov3() public {
        // -- force verbose output
        assertTrue(false);

        // -- increase balances
        yamhelper.write_balanceOf(eth_yam_lp, me, 990*10**18); // we inflate away most other holders to simulate large number of stakers

        // -- own existing incentivizer
        helper.write_flat(address(incentivizer), "owner()", me);
        assertEq(incentivizer.owner(), me);

        // -- set breaker to turn it off
        incentivizer.setBreaker(true);

        // -- get yam governance
        yamhelper.becomeGovernor(yamV3, me);
        yamV3._acceptGov();

        // -- update implementation
        yamV3._setImplementation(address(new_impl), false, "");
        address yyCRVPool = pairFor(uniFact, address(yamV3), yyCRV);
        yamV3.delegateToImplementation(abi.encodeWithSignature("assignSelfDelegate(address)", eth_yam_lp));
        assertEq(yamV3.delegates(eth_yam_lp), eth_yam_lp);

        // -- set new incentivizer
        yamV3._setIncentivizer(address(voting_inc));
        voting_inc.setRewardDistribution(me);
        assertEq(voting_inc.rewardDistribution(), me);
        voting_inc.notifyRewardAmount(0);

        // -- increase approval & stake
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 poolPower = yamV3.getCurrentVotes(eth_yam_lp);
        yamhelper.bing(); // increase block number
        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);

        // -- check voting power
        assertEq(voting_inc.getPriorVotes(me, block.number - 1), poolPower);

        // -- add another staker, that is 1% of staking pool
        user.doStake(yamhelper, address(voting_inc), 10*10**18);
        yamhelper.bing();

        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);
        assertEq(voting_inc.getPriorLPStake(address(user), block.number - 1), 10*10**18);

        // -- check voting power
        assertEq(voting_inc.getPriorVotes(me, block.number - 1), poolPower * 99 / 100);
        assertEq(voting_inc.getPriorVotes(address(user), block.number - 1), poolPower / 100);

        // -- new gov
        helper.write_flat(address(timelock), "admin()", address(gov3));
        assertEq(timelock.admin(), address(gov3));
        yamhelper.becomeGovernor(yamV3, address(timelock));
        timelock_accept_gov();
        assertEq(yamV3.gov(), address(timelock));

        // -- at this point, the new incentivizer is setup
        // the new governor is setup, me has the 90% voting power of the
        // lp pool
        // to test new gov, we need to make a new proposal and vote and check
        // vote count to see if it matches expected value

        // -- lets test with adding a new sync pair for sushiswap eth/yam

        address[] memory targets = new address[](1);
        targets[0] = address(rebaser); // rebaser
        uint256[] memory values = new uint256[](1);
        values[0] = 0; // dont send eth
        string[] memory signatures = new string[](1);
        signatures[0] = "addSyncPairs(address[],address[])"; //function to call
        bytes[] memory calldatas = new bytes[](1);
        address[] memory unis = new address[](1);
        address[] memory bal = new address[](0);
        unis[0] = address(0x95b54C8Da12BB23F7A5F6E26C38D04aCC6F81820);
        calldatas[0] = abi.encode(unis, bal); // [[[uniToAdd],[balToAdd]]]
        string memory description = "Have rebaser sync() sushiswap YAM/ETH pair";
        roll_prop(targets, values, signatures, calldatas, description);

        address[] memory pairs = rebaser.getUniSyncPairs();
        assertEq(pairs[2], unis[0]);
    }
}
