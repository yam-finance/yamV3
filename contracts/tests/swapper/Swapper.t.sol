// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import {Swapper} from "./Swapper.sol";

contract SwapperTest is YAMv3Test {
    Swapper swapper;

    function setUp() public {
        setUpCore();
        yamhelper.write_map(
            WETH,
            "balanceOf(address)",
            address(this),
            1000000 * (10**18)
        );
        swapper = new Swapper(address(this), address(this));
        IERC20(WETH).approve(address(swapper), uint256(-1));
    }

    //
    // TESTS
    //
    event TEST(bytes one, bytes two);

    function test_swapping() public {
        // -- force verbose
        assertTrue(false);
        // -- Create swap
        swapper.addSwap(
            Swapper.SwapParams({
                sourceToken: WETH,
                destinationToken: USDT,
                router: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
                pool1: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                pool2: 0x3041CbD36888bECc7bbCBc0045E3B1f144466f5f,
                sourceAmount: 100 * (10**18),
                slippageLimit: 1 * (10**16)
            })
        );

        // -- Update TWAP
        swapper.updateCumulativePrice(0);

        yamhelper.ff(90 minutes);

        // -- Attempt swap

        swapper.execute(0, 50 * (10**18), 0);
    }
}
