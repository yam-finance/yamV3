// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import { YAMIncentivizerWithVoting } from "./YAMIncentivesWithVoting.sol";
import { DualGovernorAlpha } from "./YAMGovernorAlphaWithLps.sol";
import { YAMDelegate2 } from "./YAMDelegate.sol";
import { YAMRebaser2 } from "./YAMRebaserEth.sol";
import { YAMReserves2 } from "../OTC/YAMReserves2.sol";

contract Prop2 is YAMv3Test {


    YAMIncentivizerWithVoting voting_inc;
    DualGovernorAlpha gov3;
    YAMDelegate2 new_impl;
    address public constant eth_yam_lp = address(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c);
    YAMRebaser2 eth_rebaser;
    address public constant eth_usdc_lp = address(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
    address public masterchef = address(0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd);
    address public sushi = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    address public xsushi = address(0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272);
    YAMReserves2 public r2_onchain = YAMReserves2(0x97990B693835da58A281636296D2Bf02787DEa17);

    function setUp() public {
        setUpCore();
        voting_inc = new YAMIncentivizerWithVoting();
        voting_inc.setRewardDistribution(address(timelock));
        voting_inc.transferOwnership(address(timelock));
        address[] memory incentivizers = new address[](1);
        incentivizers[0] = address(voting_inc);
        gov3 = new DualGovernorAlpha(address(timelock), address(yamV3), incentivizers);
        new_impl = new YAMDelegate2();

        // -- fully setup rebaser
        eth_rebaser = new YAMRebaser2(
          address(yamV3), // yam
          WETH, // reserve token
          uniFact, // uniswap factory
          address(reserves), // reserves contract
          gitcoinGrants, // gitcoin grant multisig
          10**16 // percentage to gitcoin grants
        );

        address[] memory uni_like = new address[](2);
        address[] memory bals = new address[](0);

        uni_like[0] = eth_yam_lp; // sushi eth/yam
        uni_like[1] = address(0xb93Cc05334093c6B3b8Bfd29933bb8d5C031caBC); // yam_yusd
        eth_rebaser.addSyncPairs(uni_like, bals);

        eth_rebaser._setPendingGov(address(timelock));
    }

    //
    // TESTS
    //

    function test_stake() public {
        uint256 printed_lp =  990*10**18;
        yamhelper.write_balanceOf(eth_yam_lp, me, printed_lp); // we inflate away most other holders to simulate large number of stakers

        // -- get yam governance
        yamhelper.becomeGovernor(address(yamV3), me);
        yamV3._acceptGov();
        helper.write_flat(address(voting_inc), "owner()", me);

        // -- set new incentivizer
        yamV3._setIncentivizer(address(voting_inc));
        voting_inc.setRewardDistribution(me);
        assertEq(voting_inc.rewardDistribution(), me);
        voting_inc.notifyRewardAmount(0);

        // -- increase approval & stake
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        uint256 pre_stake = IERC20(eth_yam_lp).balanceOf(masterchef);
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 post_stake = IERC20(eth_yam_lp).balanceOf(masterchef);

        assertEq(pre_stake + printed_lp, post_stake);

        /* uint256 poolPower = yamV3.getCurrentVotes(eth_yam_lp);
        uint256 mePower = yamV3.getCurrentVotes(me); */
        yamhelper.bing(); // increase block number
        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);
        voting_inc.exit();
    }

    function test_sweep() public {
        uint256 printed_lp =  990*10**18;
        yamhelper.write_balanceOf(eth_yam_lp, me, printed_lp); // we inflate away most other holders to simulate large number of stakers

        // -- get yam governance
        yamhelper.becomeGovernor(address(yamV3), me);
        yamV3._acceptGov();
        helper.write_flat(address(voting_inc), "owner()", me);

        // -- set new incentivizer
        yamV3._setIncentivizer(address(voting_inc));
        voting_inc.setRewardDistribution(me);
        assertEq(voting_inc.rewardDistribution(), me);
        voting_inc.notifyRewardAmount(0);

        // -- increase approval & stake
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        uint256 pre_stake = IERC20(eth_yam_lp).balanceOf(masterchef);
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 post_stake = IERC20(eth_yam_lp).balanceOf(masterchef);

        assertEq(pre_stake + printed_lp, post_stake);

        /* uint256 poolPower = yamV3.getCurrentVotes(eth_yam_lp);
        uint256 mePower = yamV3.getCurrentVotes(me); */
        yamhelper.bing(); // increase block number
        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);
        yamhelper.bong(10000);
        yamhelper.ff(10000*14);
        voting_inc.sweepToXSushi();
        assertTrue(IERC20(xsushi).balanceOf(address(voting_inc)) > 0); // got xsushi
        voting_inc.exit();

    }

    function test_sushi_to_reserves() public {
        uint256 printed_lp =  990*10**18;
        yamhelper.write_balanceOf(eth_yam_lp, me, printed_lp); // we inflate away most other holders to simulate large number of stakers

        // -- get yam governance
        yamhelper.becomeGovernor(address(yamV3), me);
        yamV3._acceptGov();
        helper.write_flat(address(voting_inc), "owner()", me);

        // -- set new incentivizer
        yamV3._setIncentivizer(address(voting_inc));
        voting_inc.setRewardDistribution(me);
        assertEq(voting_inc.rewardDistribution(), me);
        voting_inc.notifyRewardAmount(0);

        // -- increase approval & stake
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        uint256 pre_stake = IERC20(eth_yam_lp).balanceOf(masterchef);
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 post_stake = IERC20(eth_yam_lp).balanceOf(masterchef);

        assertEq(pre_stake + printed_lp, post_stake);

        /* uint256 poolPower = yamV3.getCurrentVotes(eth_yam_lp);
        uint256 mePower = yamV3.getCurrentVotes(me); */
        yamhelper.bing(); // increase block number
        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);
        yamhelper.bong(10000);
        yamhelper.ff(10000*14);
        voting_inc.sweepToXSushi();
        assertTrue(IERC20(xsushi).balanceOf(address(voting_inc)) > 0); // got xsushi
        voting_inc.sushiToReserves(uint256(-1));
        uint256 sushi_res = IERC20(sushi).balanceOf(address(r2_onchain));
        assertEq(sushi_res, 0);
        voting_inc.exit();
    }

    function test_sushi_emergency() public {
        uint256 printed_lp =  990*10**18;
        yamhelper.write_balanceOf(eth_yam_lp, me, printed_lp); // we inflate away most other holders to simulate large number of stakers

        // -- get yam governance
        yamhelper.becomeGovernor(address(yamV3), me);
        yamV3._acceptGov();
        helper.write_flat(address(voting_inc), "owner()", me);

        // -- set new incentivizer
        yamV3._setIncentivizer(address(voting_inc));
        voting_inc.setRewardDistribution(me);
        assertEq(voting_inc.rewardDistribution(), me);
        voting_inc.notifyRewardAmount(0);

        // -- increase approval & stake
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        uint256 pre_stake = IERC20(eth_yam_lp).balanceOf(masterchef);
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 post_stake = IERC20(eth_yam_lp).balanceOf(masterchef);

        assertEq(pre_stake + printed_lp, post_stake);

        /* uint256 poolPower = yamV3.getCurrentVotes(eth_yam_lp);
        uint256 mePower = yamV3.getCurrentVotes(me); */
        yamhelper.bing(); // increase block number
        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);
        yamhelper.bong(10000);
        yamhelper.ff(10000*14);
        voting_inc.sweepToXSushi();
        assertTrue(IERC20(xsushi).balanceOf(address(voting_inc)) > 0); // got xsushi
        voting_inc.emergencyMasterChefWithdraw();
        voting_inc.exit();
    }

    function test_FullProp() public {
        // -- force verbose
        assertTrue(false);

        address[] memory targets = new address[](9);
        uint256[] memory values = new uint256[](9);
        string[] memory signatures = new string[](9);
        bytes[] memory calldatas = new bytes[](9);
        string memory description = "Proposal round 2";

        // -- update rebaser
        targets[0] = address(yamV3);
        signatures[0] = "_setRebaser(address)";
        calldatas[0] = abi.encode(address(eth_rebaser));
        targets[1] = address(reserves);
        signatures[1] = "_setRebaser(address)";
        calldatas[1] = abi.encode(address(eth_rebaser));

        // -- setting implementation
        targets[2] = address(yamV3);
        signatures[2] = "_setImplementation(address,bool,bytes)";
        calldatas[2] = abi.encode(address(new_impl), false, "");

        // -- assign self delegation for eth/yam pool
        targets[3] = address(yamV3);
        calldatas[3] = abi.encodeWithSignature(
            "delegateToImplementation(bytes)",
            abi.encodeWithSignature("assignSelfDelegate(address)", eth_yam_lp)
        );

        // -- turn off old incentivizer
        targets[4] = address(incentivizer);
        signatures[4] = "setBreaker(bool)";
        calldatas[4] = abi.encode(true);

        // -- set new incentivizer
        targets[5] = address(yamV3);
        signatures[5] = "_setIncentivizer(address)";
        calldatas[5] = abi.encode(address(voting_inc));

        // -- initialize incentivizer
        targets[6] = address(voting_inc);
        signatures[6] = "notifyRewardAmount(uint256)";
        calldatas[6] = abi.encode(uint256(0));

        // -- new governor
        targets[7] = address(timelock);
        signatures[7] = "setPendingAdmin(address)";
        calldatas[7] = abi.encode(address(gov3));

        targets[8] = address(eth_rebaser);
        signatures[8] = "_acceptGov()";

        yamhelper.getQuorum(yamV3, me);

        roll_prop(
          targets,
          values,
          signatures,
          calldatas,
          description
        );

        assertEq(reserves.rebaser(), address(eth_rebaser));
        assertEq(yamV3.rebaser(), address(eth_rebaser));

        assertEq(yamV3.implementation(), address(new_impl));

        assertEq(yamV3.delegates(eth_yam_lp), eth_yam_lp);

        assertTrue(incentivizer.breaker());

        assertEq(yamV3.incentivizer(), address(voting_inc));

        assertTrue(voting_inc.initialized());

        assertEq(timelock.pendingAdmin(), address(gov3));

        gov3.__acceptAdmin();

        assertEq(timelock.admin(), address(gov3));

        // -- increase liquidity by 10x
        increase_liquidity(eth_yam_lp, 10);

        // -- initialize twap
        set_two_hop_uni_price(eth_yam_lp, eth_usdc_lp, address(yamV3), 120 * 10**16);
        eth_rebaser.init_twap();
        yamhelper.ff(12 hours);
        eth_rebaser.activate_rebasing();

        // -- fast forward to rebase
        ff_rebase();

        // -- call rebase
        eth_rebaser.rebase();

        yamhelper.bing();

        // -- get LP voting power
        yamhelper.write_balanceOf(eth_yam_lp, me, 990*10**18);
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 total_voting_pow = yamV3.getCurrentVotes(me) + voting_inc.getCurrentVotes(me);
        assertEq(total_voting_pow, gov3.getCurrentVotes(me));
        yamhelper.bing();
        assertEq(total_voting_pow, gov3.getPriorVotes(me, block.number - 1));
    }

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
        // -- delegate
        // -- check voting power
        // -- delegate self (checking for duplication)
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
        yamhelper.becomeGovernor(address(yamV3), me);
        yamV3._acceptGov();

        // -- update implementation
        yamV3._setImplementation(address(new_impl), false, "");
        /* address yyCRVPool = pairFor(uniFact, address(yamV3), yyCRV); */
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

        // -- check delegation
        user.doDelegate(address(voting_inc), me);
        assertEq(voting_inc.delegates(address(user)), me);
        yamhelper.bing();

        // -- check voting power
        assertEq(voting_inc.getPriorVotes(me, block.number - 1), poolPower);
        assertEq(voting_inc.getPriorVotes(address(user), block.number - 1), 0);

        // -- check delegation (no duplicating votes)
        voting_inc.delegate(me);
        assertEq(voting_inc.delegates(me), me);
        yamhelper.bing();

        // -- check voting power
        assertEq(voting_inc.getPriorVotes(me, block.number - 1), poolPower);
        assertEq(voting_inc.getPriorVotes(address(user), block.number - 1), 0);
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
        yamhelper.becomeGovernor(address(yamV3), me);
        yamV3._acceptGov();

        // -- update implementation
        yamV3._setImplementation(address(new_impl), false, "");
        /* address yyCRVPool = pairFor(uniFact, address(yamV3), yyCRV); */
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
        yamhelper.becomeGovernor(address(yamV3), address(timelock));
        timelock_accept_gov(address(yamV3));
        assertEq(yamV3.gov(), address(timelock));

        // -- check voting powers
        uint256 total_voting_pow = yamV3.getCurrentVotes(me) + voting_inc.getCurrentVotes(me);
        assertEq(total_voting_pow, gov3.getCurrentVotes(me));
        yamhelper.bing();
        assertEq(total_voting_pow, gov3.getPriorVotes(me, block.number - 1));


        // -- at this point, the new incentivizer is setup
        // the new governor is setup, me has the 99% voting power of the
        // lp pool

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


    function test_EthRebaser() public {
        // -- force verbose output
        /* assertTrue(false); */
        setup_rebaser();

        // increase liquidity by 10x
        increase_liquidity(eth_yam_lp, 10);

        // -- initialize twap
        set_two_hop_uni_price(eth_yam_lp, eth_usdc_lp, address(yamV3), 120 * 10**16);
        eth_rebaser.init_twap();
        yamhelper.ff(12 hours);
        assertEq(eth_rebaser.getCurrentTWAP(), 0);
        eth_rebaser.activate_rebasing();

        // -- fast forward to rebase
        ff_rebase();

        // -- call rebase x4
        eth_rebaser.rebase();
        yamhelper.ff(6 hours);
        assertEq(eth_rebaser.getCurrentTWAP(), 1);

        ff_rebase();
        eth_rebaser.rebase();
        yamhelper.ff(6 hours);
        assertEq(eth_rebaser.getCurrentTWAP(), 2);

        ff_rebase();
        eth_rebaser.rebase();


        set_two_hop_uni_price(eth_yam_lp, eth_usdc_lp, address(yamV3), 90 * 10**16);
        yamhelper.ff(6 hours);
        assertEq(eth_rebaser.getCurrentTWAP(), 3);



        ff_rebase();
        eth_rebaser.rebase();
        yamhelper.ff(6 hours);
        assertEq(eth_rebaser.getCurrentTWAP(), 4);
    }

    function setup_rebaser() public {
        // -- add sync pairs
        address[] memory uni_like = new address[](2);
        address[] memory bals = new address[](0);

        uni_like[0] = address(0x95b54C8Da12BB23F7A5F6E26C38D04aCC6F81820); // sushi eth/yam
        uni_like[1] = address(0xb93Cc05334093c6B3b8Bfd29933bb8d5C031caBC); // yam_yusd
        eth_rebaser.addSyncPairs(uni_like, bals);

        // -- update reserves & yam rebaser
        atomicGov(address(reserves), "_setRebaser(address)", address(eth_rebaser));
        atomicGov(address(yamV3), "_setRebaser(address)", address(eth_rebaser));
    }
}
