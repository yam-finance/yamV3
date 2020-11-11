// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import {VestingPool} from "./VestingPool.sol";
import {YAM} from "../../token/YAM.sol";

contract VestingPoolTest is YAMv3Test {
    VestingPool vestingPool;

    function setUp() public {
        setUpCore();
        vestingPool = new VestingPool(address(this), YAM(address(yamV3)));
        yamhelper.write_balanceOfUnderlying(
            address(yamV3),
            address(vestingPool),
            100000000000000000000000000
        );
        yamhelper.write_balanceOfUnderlying(
            address(yamV3),
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
            0
        );
    }

    //
    // TESTS
    //
    function test_streamLifeCycle() public {
        // -- force verbose
        assertTrue(false);
        uint256 poolId = vestingPool.openStream(
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
            60 * 60 * 24 * 365,
            100000000000000000000000000
        );
        yamhelper.ff(60 * 60 * 24);
        uint256 claimableUnderlying;
        uint256 claimableBalance;
        (claimableUnderlying, claimableBalance) = vestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 273972602739726027345751);

        vestingPool.payout(poolId);
        (claimableUnderlying, claimableBalance) = vestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 0);

        yamhelper.ff(60 * 60 * 24 * 364);
        (claimableUnderlying, claimableBalance) = vestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 99726027397260273972654248);

        vestingPool.payout(poolId);
        (claimableUnderlying, claimableBalance) = vestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 0);
        assertEq(yamV3.balanceOfUnderlying(address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)), 99999999999999999999999999); // I expected to be slightly less than 100*10^24 due to fragment/yam conversion, but it's slightly more?
    }
}
