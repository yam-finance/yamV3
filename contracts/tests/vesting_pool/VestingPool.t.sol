// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import {VestingPool} from "./VestingPool.sol";
import {YAMDelegate2} from "../proposal_round_2/YAMDelegate.sol";

contract VestingPoolTest is YAMv3Test {
    VestingPool vestingPool;
    YAMDelegate2 yam;
    ProxyContract proxy;

    function setUp() public {
        setUpCore();
        vestingPool = new VestingPool(YAMDelegate2(address(yamV3)));
        proxy = new ProxyContract(address(vestingPool));
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
        yam = YAMDelegate2(address(yamV3));
        // -- get yam governance
        yamhelper.becomeGovernor(address(yamV3), me);
        yamV3._acceptGov();

        // -- update implementation
        yamV3._setImplementation(address(new YAMDelegate2()), false, "");
    }

    //
    // TESTS
    //
    event TEST(bytes one, bytes two);

    function test_streamCreationNonGov() public {
        // -- force verbose
        assertTrue(false);
        // -- Try to create stream through non-gov proxy, check if it correctly reverts and the error is correct
        (bool success, bytes memory returnData) = address(proxy).call( // This creates a low level call to the token
            abi.encodePacked( // This encodes the function to call and the parameters to pass to that function
                vestingPool.openStream.selector, // This is the function identifier of the function we want to call
                abi.encode(
                    address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
                    uint128(60 * 60 * 24 * 365),
                    uint256(100000000000000000000000000)
                ) // This encodes the parameters we want to pass to the function
            )
        );
        assertTrue(!success);
        bytes memory errorString = hex"08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003c56657374696e67506f6f6c3a3a63616e4d616e61676553747265616d733a206163636f756e742063616e6e6f74206d616e6167652073747265616d7300000000";
        assertEq0(returnData, errorString);
    }

    function test_streamLifeCycleByGov() public {
        // -- force verbose
        assertTrue(false);

        // -- Open stream
        uint256 poolId = vestingPool.openStream(
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
            60 * 60 * 24 * 365,
            100000000000000000000000000
        );

        // -- Fast forward part way, check if claimable amount is accurate
        yamhelper.ff(60 * 60 * 24);
        uint256 claimableUnderlying;
        claimableUnderlying = vestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 273972602739726027397260);

        // -- Payout, check if claimable amount is accurate
        vestingPool.payout(poolId);
        claimableUnderlying = vestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 0);

        // -- Fast forward past end, check if claimable amount is accurate
        yamhelper.ff(60 * 60 * 24 * 400);
        claimableUnderlying = vestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 99726027397260273972602740);

        // -- Payout, check if balance and claimable are correct
        vestingPool.payout(poolId);
        claimableUnderlying = vestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 0);
        assertEq(
            yamV3.balanceOfUnderlying(
                address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
            ),
            100000000000000000000000000
        );
    }

    function test_streamLifeCycleBySubGov() public {
        // -- force verbose
        assertTrue(false);

        // -- Set sub gov, cast proxy as VestingPool
        vestingPool.setSubGov(address(proxy), true);
        VestingPool proxyVestingPool = VestingPool(address(proxy));

        // -- Open stream
        uint256 poolId = proxyVestingPool.openStream(
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
            60 * 60 * 24 * 365,
            100000000000000000000000000
        );
        // -- Fast forward part way, check if claimable amount is accurate
        yamhelper.ff(60 * 60 * 24);
        uint256 claimableUnderlying;
        claimableUnderlying = proxyVestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 273972602739726027397260);

        // -- Payout, check if claimable amount is accurate
        proxyVestingPool.payout(poolId);
        claimableUnderlying = proxyVestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 0);

        // -- Fast forward past end, check if claimable amount is accurate
        yamhelper.ff(60 * 60 * 24 * 400);
        claimableUnderlying = proxyVestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 99726027397260273972602740);

        // -- Payout, check if balance and claimable are correct
        proxyVestingPool.payout(poolId);
        claimableUnderlying = proxyVestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 0);
        assertEq(
            yamV3.balanceOfUnderlying(
                address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
            ),
            100000000000000000000000000
        );
    }

    function test_streamClose() public {
        // -- force verbose
        assertTrue(false);

        // -- Open pool
        uint256 poolId = vestingPool.openStream(
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
            60 * 60 * 24 * 365,
            100000000000000000000000000
        );

        // -- Fast forward, check if claimable amount is accurate
        yamhelper.ff(60 * 60 * 24);
        uint256 claimableUnderlying;
        claimableUnderlying = vestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 273972602739726027397260);

        // -- Close stream, check if claimable amount and balance are accurate
        vestingPool.closeStream(poolId);
        claimableUnderlying = vestingPool.claimable(poolId);
        assertEq(claimableUnderlying, 0);
        assertEq(
            yamV3.balanceOfUnderlying(
                address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
            ),
            273972602739726027397260
        );

        // -- Get stream, everything should be zero'd
        address recipient;
        uint128 startTime;
        uint128 length;
        uint256 totalAmount;
        uint256 amountPaidOut;

        (recipient, startTime, length, totalAmount, amountPaidOut) = vestingPool
            .streams(poolId);
        assertEq(recipient, address(0x0000000000000000000000000000000000000000));
        assertEq(uint256(startTime), 0);
        assertEq(uint256(length), 0);
        assertEq(totalAmount, 0);
        assertEq(amountPaidOut, 0);
    }
}

// Used as "secondary address" for testing access control
contract ProxyContract {
    address target;

    constructor(address _target) public {
        target = _target;
    }

    function() external payable {
        assembly {
            calldatacopy(0x0, 0x0, calldatasize)
            let result := call(gas, sload(target_slot), 0, 0x0, calldatasize, 0x0, 0)
            returndatacopy(0x0, 0x0, returndatasize)
            switch result case 0 {revert(0, returndatasize)} default {return (0, returndatasize)}
        }
    }
}
