// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import {IERC20} from "../../lib/IERC20.sol";
import {SetJoiner} from "./SetJoiner.sol";
import {UMAFarmingMar} from "../uma_farming/UMAFarmingMar.sol";

// Prop for December contributor payment and stream setup
contract Prop10 is YAMv3Test {
    address expenseFund = 0x744D16d200175d20E6D8e5f405AEfB4EB7A962d1;
    address rescuee = 0x93b7eB9764aa645e309D68305B10B6A3c01A71ce;

    function setUp() public {
        setUpCore();
    }

    event TEST(
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        string description
    );

    /**
     * Summary:
     * 1. Rescue YAMv2 sent to contract
     * 2.
     **/
    function test_prop_10() public {
        assertTrue(false);

        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        string[] memory signatures = new string[](3);
        bytes[] memory calldatas = new bytes[](3);

        IERC20 yamv2 = IERC20(0xAba8cAc6866B83Ae4eec97DD07ED254282f6aD8A);

        uint256 yamPreBalance = yamv2.balanceOf(rescuee);

            string memory description
         = "Rescue YAMv2 sent to contract, setup instant stream for expense fund, send yUSD to expense fund";

        // -- Rescue yamv2 sent to yamv3 contract
        targets[0] = address(yamV3);
        values[0] = 0;
        signatures[0] = "rescueTokens(address,address,uint256)";
        calldatas[0] = abi.encode(
            address(yamv2),
            rescuee,
            107817177800000000000000000
        );

        // -- Create instant stream for funding YAM to expense fund

        targets[1] = address(vestingPool);
        values[1] = 0;
        signatures[1] = "openStream(address,uint128,uint256)";
        calldatas[1] = abi.encode(
            expenseFund,
            0,
            11993650796837519588360955870
        );

        // -- Transfer 4100 (~$5k) yUSD to expense fund
        address[] memory whos = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory tokens = new address[](1);
        whos[0] = expenseFund;
        amounts[0] = 4100 * (10**18);
        tokens[0] = yyCRV;

        targets[2] = address(reserves);
        values[2] = 0;
        signatures[2] = "oneTimeTransfers(address[],uint256[],address[])";
        calldatas[2] = abi.encode(whos, amounts, tokens);

        emit TEST(targets, values, signatures, calldatas, description);
        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description);

        vestingPool.payout(26);

        uint256 yamPostBalance = yamv2.balanceOf(rescuee);

        assertEq(yamPostBalance - yamPreBalance, 107817177800000000000000000);
        assertEq(yamV3.balanceOf(expenseFund), 30000 * (10**18));
        assertEq(IERC20(yyCRV).balanceOf(expenseFund), 4100 * (10**18));
    }

     function test_created_prop_10() public {
        assertTrue(false);

        // Set votes very high
        hevm.store(
            address(governor),
            bytes32(
                0x791a16d3e68c61bb9d35234523f8c9d83d2891482fd697c274e6fea9c60a1527
            ),
            bytes32(
                0x000000000000000000000000000000000000000dd86e9a6e3a129a6d14c5ee21
            )
        );
        hevm.store(
            address(governor),
            bytes32(
                0x89832631fb3c3307a103ba2c84ab569c64d6182a18893dcd163f0f1c20907343
            ),
            bytes32(
                0x000000000000000000000000000000000000000dd86e9a6e3a129a6d14c5ee21
            )
        );

        IERC20 yamv2 = IERC20(0xAba8cAc6866B83Ae4eec97DD07ED254282f6aD8A);

        uint256 yamPreBalance = yamv2.balanceOf(rescuee);

        governor.castVote(2,true);
        yamhelper.bong(12345);

        governor.queue(2);
        yamhelper.ff(60 * 60 * 12);
        governor.execute(2);
        

        vestingPool.payout(26);

        uint256 yamPostBalance = yamv2.balanceOf(rescuee);

        assertEq(yamPostBalance - yamPreBalance, 107817177800000000000000000);
        assertEq(yamV3.balanceOf(expenseFund), 30000 * (10**18));
        assertEq(IERC20(yyCRV).balanceOf(expenseFund), 4100 * (10**18));
    }
}
