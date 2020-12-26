// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import {IERC20} from "../../lib/IERC20.sol";

// Prop for switching from original INDEX incentivizer to new one
contract Prop5 is YAMv3Test {
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
     * 1. Rescue USDC
     * 2. Refund eth for yamv3 deployment costs
     * 3. Disable rebase
     **/
    function test_onchain_prop_5() public {
        assertTrue(false);
        uint256 preWethBalance = IERC20(WETH).balanceOf(
            0x46499275b5c4d67dfa46B92D89aADA3158ea392e
        );
        uint256 preUsdcBalance = IERC20(USDC).balanceOf(
            0xeE39ED26d4dE5A77A6f5Efa6fA59b8489A678d89
        );
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        string[] memory signatures = new string[](3);
        bytes[] memory calldatas = new bytes[](3);

        string memory description = "Rescue USDC, refund contributor for deployment costs, disable rebase";

        // -- Rescue USDC
        targets[0] = address(yamV3);
        values[0] = 0;
        signatures[0] = "rescueTokens(address,address,uint256)";
        calldatas[0] = abi.encode(
            address(USDC),
            0xeE39ED26d4dE5A77A6f5Efa6fA59b8489A678d89,
            8700 * (10**6)
        );

        // -- Refund WETH for yam deployment costs
        targets[1] = address(reserves);
        values[1] = 0;
        signatures[1] = "oneTimeTransfers(address[],uint256[],address[])";
        address[] memory whos = new address[](1);
        whos[0] = address(0x46499275b5c4d67dfa46B92D89aADA3158ea392e);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = uint256(15 ether);
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        calldatas[1] = abi.encode(whos, amounts, tokens);

        // -- Disable rebase
        targets[2] = address(yamV3);
        values[2] = 0;
        signatures[2] = "_setRebaser(address)";
        calldatas[2] = abi.encode(address(0x0));

        emit TEST(targets, values, signatures, calldatas, description);
        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description);


        // Assert WETH distributed properly
        uint256 postWethBalance = IERC20(WETH).balanceOf(
            0x46499275b5c4d67dfa46B92D89aADA3158ea392e
        );
        assertEq(postWethBalance - preWethBalance, 15 ether);

        // Assert USDC recovered properly
        uint256 postUsdcBalance = IERC20(USDC).balanceOf(
            0xeE39ED26d4dE5A77A6f5Efa6fA59b8489A678d89
        );
        assertEq(postUsdcBalance - preUsdcBalance, 8700 * (10**6));
        assertEq(IERC20(USDC).balanceOf(address(reserves)), 0);

        // Assert rebaser set correctly
        assertEq(yamV3.rebaser(), address(0x0));
    }
}
