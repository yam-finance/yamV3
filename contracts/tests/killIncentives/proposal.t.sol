// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";

contract KillIncentives is YAMv3Test {

    function setUp() public {
        setUpCore();
    }

    //
    // TESTS
    //
    function test_kill() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        string[] memory signatures = new string[](2);
        bytes[] memory calldatas = new bytes[](2);
        string memory description = "Stop LP Incentives & sync Sushi YAM/ETH";




        targets[0] = address(incentivizer);
        signatures[0] = "setBreaker(bool)";
        calldatas[0] = abi.encode(true);

        targets[1] = address(rebaser);
        signatures[1] = "addSyncPairs(address[],address[])"; //function to call
        address[] memory unis = new address[](1);
        address[] memory bal = new address[](0);
        unis[0] = address(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c);
        /* unis[0] = pairForSushi(address(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac), address(yamV3), address(WETH)); */
        calldatas[1] = abi.encode(unis, bal); // [[[uniToAdd],[balToAdd]]]

        stake();
        user.doStake(yamhelper, address(incentivizer), 10*10**18);

        yamhelper.getQuorum(yamV3, me);

        roll_prop(
          targets,
          values,
          signatures,
          calldatas,
          description
        );

        assertEq(rebaser.getUniSyncPairs()[2], address(0));
        assertEq(rebaser.getUniSyncPairs()[2], unis[0]);

        ff_rebase();
        set_uni_price(
            rebaser.uniswap_pair(),
            address(yamV3),
            105 * 10**16
        );
        rebaser.rebase();

        ff_rebase();


        {
            uint256 pre_bal = yamV3.balanceOf(unis[0]);
            (uint256 pre_resA, uint256 pre_resB, ) = UniswapPair(unis[0]).getReserves();
            rebaser.rebase();
            uint256 post_bal = yamV3.balanceOf(unis[0]);
            (uint256 post_resA, uint256 post_resB, ) = UniswapPair(unis[0]).getReserves();
            assertEq(pre_resA, 0);
            assertEq(pre_resB, 1);
            assertEq(post_resA, 2);
            assertEq(post_resB, 3);
            assertEq(pre_bal, 4);
            assertEq(post_bal, 5);
        }



        assertTrue(incentivizer.breaker() == true);

        uint256 end_time = incentivizer.periodFinish();

        assertEq(incentivizer.earned(me), 0);

        // go to end of period
        yamhelper.ff(end_time - now);

        incentivizer.getReward();
        user.doGetReward(address(incentivizer));

        yamhelper.ff(86400);

        assertEq(incentivizer.earned(me), 0);
        assertEq(incentivizer.earned(address(user)), 0);
    }

    function stake() public {
        address uni = address(incentivizer.uni_lp());
        yamhelper.write_balanceOf(uni, me, 100*10**18);
        IERC20(uni).approve(address(incentivizer), uint256(-1));
        incentivizer.stake(100*10**18);
    }
}
