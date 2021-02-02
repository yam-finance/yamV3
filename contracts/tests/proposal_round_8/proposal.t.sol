// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import {IERC20} from "../../lib/IERC20.sol";
import {BulkPayer} from "./BulkPayer.sol";

// Prop for December contributor payment and stream setup
contract Prop6 is YAMv3Test {
    BulkPayer bulkPayer = BulkPayer(0xbbd3933ceA86ec6fFe722F817034C469bCbaF4C4);

    YamGovernorAlpha newGovernor = YamGovernorAlpha(
        0x2DA253835967D6E721C6c077157F9c9742934aeA
    );

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
     * 1. Give BulkPayer permissions to pay
     * 2. Give BulkPayer permissions to create streams
     * 3. Execute BulkPayer, pays out past vested YAM and sets up ongoing streams
     * 4. Set new Governor as pending admin
     **/
    function test_onchain_prop_8() public {
        assertTrue(false);

        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        string[] memory signatures = new string[](4);
        bytes[] memory calldatas = new bytes[](4);

        uint256[] memory preYUSDBalances = getYUSDBalances();
        uint256[] memory preYamBOUBalances = getBOUBalances();


            string memory description
         = "Pay contributors, upgrade Governor with new guardian";

        // -- Give permissions for BulkPayer on VestingPool
        targets[0] = address(monthlyAllowance);
        values[0] = 0;
        signatures[0] = "setIsSubGov(address,bool)";
        calldatas[0] = abi.encode(address(bulkPayer), true);

        // -- Give permissions for BulkPayer on VestingPool
        targets[1] = address(vestingPool);
        values[1] = 0;
        signatures[1] = "setSubGov(address,bool)";
        calldatas[1] = abi.encode(address(bulkPayer), true);

        // -- Execute BulkPayer
        targets[2] = address(bulkPayer);
        values[2] = 0;
        signatures[2] = "execute()";
        calldatas[2] = "";

        targets[3] = address(timelock);
        values[3] = 0;
        signatures[3] = "setPendingAdmin(address)";
        calldatas[3] = abi.encode(newGovernor);

        emit TEST(targets, values, signatures, calldatas, description);
        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description);

        // Assert backpay streams payed out the proper amount
        uint256[] memory postYamBOUBalances = getBOUBalances();

        assertEq(
            postYamBOUBalances[0] - preYamBOUBalances[0],
            134146341463000000000000000
        );
        assertEq(
            postYamBOUBalances[1] - preYamBOUBalances[1],
            182926829268000000000000000
        );

        // -- Assert YUSD payments
        uint256[] memory postYUSDBalances = getYUSDBalances();

        assertEq(
            postYUSDBalances[0] - preYUSDBalances[0],
            yearlyUSDToMonthlyYUSD(140000 * (10**18))
        );

        assertEq(
            postYUSDBalances[1] - preYUSDBalances[1],
            yearlyUSDToMonthlyYUSD(120000 * (10**18))
        );

        assertEq(
            postYUSDBalances[2] - preYUSDBalances[2],
            yearlyUSDToMonthlyYUSD(105000 * (10**18))
        );

        assertEq(
            postYUSDBalances[3] - preYUSDBalances[3],
            yearlyUSDToMonthlyYUSD(72000 * (10**18))
        );

        assertEq(
            postYUSDBalances[4] - preYUSDBalances[4],
            yearlyUSDToMonthlyYUSD(84000 * (10**18))
        );

        assertEq(
            postYUSDBalances[5] - preYUSDBalances[5],
            yearlyUSDToMonthlyYUSD(30000 * (10**18))
        );

        assertNewGovernorWorks();
    }

    function assertNewGovernorWorks() internal {
        hevm.store(
            address(newGovernor),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000002),
            bytes32(
                0x000000000000000000000000683A78bA1f6b25E29fbBC9Cd1BFA29A51520De84
            )
        );
        newGovernor.__acceptAdmin();
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);

        uint256[] memory preYUSDBalances = getYUSDBalances();
        uint256[] memory preYamBOUBalances = getBOUBalances();

        string memory description = "Test";

        // -- Give permissions for BulkPayer on VestingPool
        targets[0] = address(monthlyAllowance);
        values[0] = 0;
        signatures[0] = "setIsSubGov(address,bool)";
        calldatas[0] = abi.encode(address(bulkPayer), true);
        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description);


    }

    function getBOUBalances() internal returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](12);

        balances[0] = yamV3.balanceOfUnderlying(
            0x43fD74401B4BF04095590a5308B6A5e3Db44b9e3
        );
        balances[1] = yamV3.balanceOfUnderlying(
            0x0A1382a504f41BcA6fF1D44b7BDbA06c5Aa3Ca65
        );

        return balances;
    }

    function getYUSDBalances() internal returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](6);
        IERC20 YUSD = IERC20(yyCRV);
        balances[0] = YUSD.balanceOf(
            0x4a29e88cEA7e1505DB9b6491C749Fb5d6d595265
        );
        balances[1] = YUSD.balanceOf(
            0x8A8acf1cEcC4ed6Fe9c408449164CE2034AdC03f
        );
        balances[2] = YUSD.balanceOf(
            0xEC3281124d4c2FCA8A88e3076C1E7749CfEcb7F2
        );
        balances[3] = YUSD.balanceOf(
            0xbdac5657eDd13F47C3DD924eAa36Cf1Ec49672cc
        );
        balances[4] = YUSD.balanceOf(
            0x01e0C7b70E0E05a06c7cC8deeb97Fa03d6a77c9C
        );
        balances[5] = YUSD.balanceOf(
            0xcc506b3c2967022094C3B00276617883167BF32B
        );

        return balances;
    }

    function yearlyUSDToMonthlyYUSD(uint256 yearlyUSD)
        internal
        pure
        returns (uint256)
    {
        // * 100 / 119 accounts for the yUSD price
        return ((yearlyUSD / uint256(12)) * 100) / uint256(120);
    }
}
