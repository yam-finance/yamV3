// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import {MonthlyAllowance} from "./MonthlyAllowance.sol";
import {IERC20} from "../../lib/IERC20.sol";

contract MonthlyAllowanceTest is YAMv3Test {
    MonthlyAllowance monthlyAllowance;
    ProxyContract proxy;
    IERC20 yUSD = IERC20(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);

    function setUp() public {
        setUpCore();
        monthlyAllowance = new MonthlyAllowance(address(yUSD), address(this));
        proxy = new ProxyContract(address(monthlyAllowance));
        yamhelper.write_balanceOf(
            address(yUSD),
            address(this),
            1000000000000000000000000000000000000
        );
        yamhelper.write_balanceOf(
            address(yUSD),
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
            0
        );
        yUSD.approve(address(monthlyAllowance), 1000000000000000000000000000000000000);
        monthlyAllowance.setIsSubGov(address(proxy), true);
    }

    //
    // TESTS
    //
    event TEST(bytes one, bytes two);
    event BALANCE(uint256 balance);

    function test_paymentsByGov() public {
        // -- force verbose
        assertTrue(false);

        // -- Check to make sure contract isn't initialized yet
        assertTrue(!monthlyAllowance.initialized());
        assertEq(monthlyAllowance.timeInitialized(), 0);

        // -- Try to make payment, check if correctly reverts since it's not initialized
        (bool success1, bytes memory returnData1) = address(monthlyAllowance).call( // This creates a low level call to the token
            abi.encodePacked( // This encodes the function to call and the parameters to pass to that function
                monthlyAllowance.pay.selector, // This is the function identifier of the function we want to call
                abi.encode(
                    address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
                    uint256(100 ether)
                ) // This encodes the parameters we want to pass to the function
            )
        );
        assertTrue(!success1);
        bytes memory errorString1 = hex"08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002f4d6f6e74686c79416c6c6f77616e63653a3a7061793a20436f6e7472616374206e6f7420696e697469616c697a65640000000000000000000000000000000000";
        assertEq0(returnData1, errorString1);

        // -- Initialize, check if initialization worked correctly and verify epoch
        monthlyAllowance.initialize();
        assertTrue(monthlyAllowance.initialized());
        assertEq(monthlyAllowance.timeInitialized(), block.timestamp);

        // -- Do payment of 90k, verify payout was correct
        monthlyAllowance.pay(address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), 90000 ether);
        assertEq(yUSD.balanceOf(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), 90000 ether);

        // -- Do payment of 20k, verify if failed correctly
        (bool success2, bytes memory returnData2) = address(monthlyAllowance).call( // This creates a low level call to the token
            abi.encodePacked( // This encodes the function to call and the parameters to pass to that function
                monthlyAllowance.pay.selector, // This is the function identifier of the function we want to call
                abi.encode(
                    address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
                    uint256(20000 ether)
                ) // This encodes the parameters we want to pass to the function
            )
        );
        assertTrue(!success2);
        bytes memory errorString2 = hex"08c379a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000314d6f6e74686c79416c6c6f77616e63653a3a7061793a204d6f6e74686c7920616c6c6f77616e6365206578636565646564000000000000000000000000000000";
        assertEq0(returnData2, errorString2);

        // -- Fast forward 1 month, retest everything
        yamhelper.ff(60 * 60 * 24*30);
        assertEq(monthlyAllowance.currentEpoch(), 1);

        // -- Do payment of 90k, verify payout was correct
        monthlyAllowance.pay(address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), 90000 ether);
        assertEq(yUSD.balanceOf(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), 180000 ether);

        // -- Do payment of 20k, verify if failed correctly
        (bool success3, bytes memory returnData3) = address(monthlyAllowance).call( // This creates a low level call to the token
            abi.encodePacked( // This encodes the function to call and the parameters to pass to that function
                monthlyAllowance.pay.selector, // This is the function identifier of the function we want to call
                abi.encode(
                    address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
                    uint256(20000 ether)
                ) // This encodes the parameters we want to pass to the function
            )
        );

        assertTrue(!success3);
        bytes memory errorString3 = hex"08c379a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000314d6f6e74686c79416c6c6f77616e63653a3a7061793a204d6f6e74686c7920616c6c6f77616e6365206578636565646564000000000000000000000000000000";
        assertEq0(returnData3, errorString3);

        // -- Fast forward 1 month, flip breaker, verify correct error happened
        yamhelper.ff(60*60*24*30);
        assertEq(monthlyAllowance.currentEpoch(), 2);

        monthlyAllowance.flipBreaker();

        (bool success4, bytes memory returnData4) = address(monthlyAllowance).call( // This creates a low level call to the token
            abi.encodePacked( // This encodes the function to call and the parameters to pass to that function
                monthlyAllowance.pay.selector, // This is the function identifier of the function we want to call
                abi.encode(
                    address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
                    uint256(20000 ether)
                ) // This encodes the parameters we want to pass to the function
            )
        );

        assertTrue(!success4);
        bytes memory errorString4 = hex"08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002f4d6f6e74686c79416c6c6f77616e63653a3a627265616b65724e6f745365743a20627265616b6572206973207365740000000000000000000000000000000000";
        assertEq0(returnData4, errorString4);
    }

    function test_paymentsBySubGov() public {
        // -- force verbose
        assertTrue(false);
        MonthlyAllowance proxyAllowance = MonthlyAllowance(address(monthlyAllowance));
        // -- Check to make sure contract isn't initialized yet
        assertTrue(!proxyAllowance.initialized());
        assertEq(proxyAllowance.timeInitialized(), 0);

        // -- Try to make payment, check if correctly reverts since it's not initialized
        (bool success1, bytes memory returnData1) = address(proxyAllowance).call( // This creates a low level call to the token
            abi.encodePacked( // This encodes the function to call and the parameters to pass to that function
                proxyAllowance.pay.selector, // This is the function identifier of the function we want to call
                abi.encode(
                    address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
                    uint256(100 ether)
                ) // This encodes the parameters we want to pass to the function
            )
        );
        assertTrue(!success1);
        bytes memory errorString1 = hex"08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002f4d6f6e74686c79416c6c6f77616e63653a3a7061793a20436f6e7472616374206e6f7420696e697469616c697a65640000000000000000000000000000000000";
        assertEq0(returnData1, errorString1);

        // -- Initialize, check if initialization worked correctly and verify epoch
        proxyAllowance.initialize();
        assertTrue(proxyAllowance.initialized());
        assertEq(proxyAllowance.timeInitialized(), block.timestamp);

        // -- Do payment of 90k, verify payout was correct
        proxyAllowance.pay(address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), 90000 ether);
        assertEq(yUSD.balanceOf(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), 90000 ether);

        // -- Do payment of 20k, verify if failed correctly
        (bool success2, bytes memory returnData2) = address(proxyAllowance).call( // This creates a low level call to the token
            abi.encodePacked( // This encodes the function to call and the parameters to pass to that function
                proxyAllowance.pay.selector, // This is the function identifier of the function we want to call
                abi.encode(
                    address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
                    uint256(20000 ether)
                ) // This encodes the parameters we want to pass to the function
            )
        );
        assertTrue(!success2);
        bytes memory errorString2 = hex"08c379a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000314d6f6e74686c79416c6c6f77616e63653a3a7061793a204d6f6e74686c7920616c6c6f77616e6365206578636565646564000000000000000000000000000000";
        assertEq0(returnData2, errorString2);

        // -- Fast forward 1 month, retest everything
        yamhelper.ff(60 * 60 * 24*30);
        assertEq(proxyAllowance.currentEpoch(), 1);

        // -- Do payment of 90k, verify payout was correct
        proxyAllowance.pay(address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), 90000 ether);
        assertEq(yUSD.balanceOf(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), 180000 ether);

        // -- Do payment of 20k, verify if failed correctly
        (bool success3, bytes memory returnData3) = address(proxyAllowance).call( // This creates a low level call to the token
            abi.encodePacked( // This encodes the function to call and the parameters to pass to that function
                proxyAllowance.pay.selector, // This is the function identifier of the function we want to call
                abi.encode(
                    address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
                    uint256(20000 ether)
                ) // This encodes the parameters we want to pass to the function
            )
        );

        assertTrue(!success3);
        bytes memory errorString3 = hex"08c379a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000314d6f6e74686c79416c6c6f77616e63653a3a7061793a204d6f6e74686c7920616c6c6f77616e6365206578636565646564000000000000000000000000000000";
        assertEq0(returnData3, errorString3);

        // -- Fast forward 1 month, flip breaker, verify correct error happened
        yamhelper.ff(60*60*24*30);
        assertEq(proxyAllowance.currentEpoch(), 2);

        proxyAllowance.flipBreaker();

        (bool success4, bytes memory returnData4) = address(proxyAllowance).call( // This creates a low level call to the token
            abi.encodePacked( // This encodes the function to call and the parameters to pass to that function
                proxyAllowance.pay.selector, // This is the function identifier of the function we want to call
                abi.encode(
                    address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
                    uint256(20000 ether)
                ) // This encodes the parameters we want to pass to the function
            )
        );

        assertTrue(!success4);
        bytes memory errorString4 = hex"08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002f4d6f6e74686c79416c6c6f77616e63653a3a627265616b65724e6f745365743a20627265616b6572206973207365740000000000000000000000000000000000";
        assertEq0(returnData4, errorString4);
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
