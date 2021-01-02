// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import {IERC20} from "../../lib/IERC20.sol";
import {BulkVestingSetup} from "./BulkVestingSetup.sol";

// Prop for December contributor payment and stream setup
contract Prop6 is YAMv3Test {
    BulkVestingSetup vestingSetup = BulkVestingSetup(
        0xCAcD8b04D4Ada8140FFD3A752D814c6ABe875ed8
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
     * 1. Give BulkVestingSetup permissions to create streams
     * 2. Execute BulkVestingSetup, pays out past vested YAM and sets up ongoing streams
     * 3. Pay YUSD compensated contributors
     **/
    function test_onchain_prop_6() public {
        assertTrue(false);

        address[] memory targets = new address[](9);
        uint256[] memory values = new uint256[](9);
        string[] memory signatures = new string[](9);
        bytes[] memory calldatas = new bytes[](9);

        uint256[] memory preYamBOUBalances = getBOUBalances();
        uint256[] memory preYUSDBalances = getYUSDBalances();


            string memory description
         = "Give BulkVestingSetup permissions, execute BulkVestingSetup, send monthly payments";

        // -- Give permissions for BulkVestingSetup
        targets[0] = address(vestingPool);
        values[0] = 0;
        signatures[0] = "setSubGov(address,bool)";
        calldatas[0] = abi.encode(address(vestingSetup), true);

        // -- Initialize MonthlyAllowance
        targets[1] = address(monthlyAllowance);
        values[1] = 0;
        signatures[1] = "initialize()";
        calldatas[1] = "";

        // -- Execute BulkVestingSetup
        targets[2] = address(vestingSetup);
        values[2] = 0;
        signatures[2] = "execute()";
        calldatas[2] = "";

        // -- Send contributor monthly payments
        add_payments(targets, signatures, calldatas);

        emit TEST(targets, values, signatures, calldatas, description);
        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description);

        // Assert backpay streams payed out the proper amount
        uint256[] memory postYamBOUBalances = getBOUBalances();

        assertEq(
            postYamBOUBalances[0] - preYamBOUBalances[0],
            (30000 * (10**24)) / uint256(12)
        );
        assertEq(
            postYamBOUBalances[1] - preYamBOUBalances[1],
            uint256((25000 * (10**24)) / uint256(12))
        );
        assertEq(
            postYamBOUBalances[2] - preYamBOUBalances[2],
            uint256((25000 * (10**24)) / uint256(12))
        );
        assertEq(
            postYamBOUBalances[3] - preYamBOUBalances[3],
            uint256((30000 * (10**24)) / uint256(12))
        );
        assertEq(
            postYamBOUBalances[4] - preYamBOUBalances[4],
            uint256((30000 * (10**24)) / uint256(12))
        );
        assertEq(
            postYamBOUBalances[5] - preYamBOUBalances[5],
            uint256((25000 * (10**24)) / uint256(12))
        );
        assertEq(
            postYamBOUBalances[6] - preYamBOUBalances[6],
            uint256((5000 * (10**24)) / uint256(12))
        );
        assertEq(
            postYamBOUBalances[7] - preYamBOUBalances[7],
            uint256((15000 * (10**24)) / uint256(12))
        );
        assertEq(
            postYamBOUBalances[8] - preYamBOUBalances[8],
            uint256((15000 * (10**24)) / uint256(12))
        );
        assertEq(
            postYamBOUBalances[9] - preYamBOUBalances[9],
            uint256((15000 * (10**24)) / uint256(12))
        );
        assertEq(
            postYamBOUBalances[10] - preYamBOUBalances[10],
            uint256((12000 * (10**24)) / uint256(12))
        );
        assertEq(
            postYamBOUBalances[11] - preYamBOUBalances[11],
            uint256((10000 * (10**24)) / uint256(12))
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

        // -- Assert streams created properly
        assertOngoingStreams();
    }

    function yearlyUSDToMonthlyYUSD(uint256 yearlyUSD)
        internal
        view
        returns (uint256)
    {
        // * 100 / 119 accounts for the yUSD price
        return ((yearlyUSD / uint256(12)) * 100) / uint256(119);
    }

    function add_payments(
        address[] memory targets,
        string[] memory signatures,
        bytes[] memory calldatas
    ) internal {
        add_payment(
            targets,
            signatures,
            calldatas,
            0x4a29e88cEA7e1505DB9b6491C749Fb5d6d595265,
            yearlyUSDToMonthlyYUSD(140000 * (10**18))
        );
        add_payment(
            targets,
            signatures,
            calldatas,
            0x8A8acf1cEcC4ed6Fe9c408449164CE2034AdC03f,
            yearlyUSDToMonthlyYUSD(120000 * (10**18))
        );
        add_payment(
            targets,
            signatures,
            calldatas,
            0xEC3281124d4c2FCA8A88e3076C1E7749CfEcb7F2,
            yearlyUSDToMonthlyYUSD(105000 * (10**18))
        );
        add_payment(
            targets,
            signatures,
            calldatas,
            0xbdac5657eDd13F47C3DD924eAa36Cf1Ec49672cc,
            yearlyUSDToMonthlyYUSD(72000 * (10**18))
        );
        add_payment(
            targets,
            signatures,
            calldatas,
            0x01e0C7b70E0E05a06c7cC8deeb97Fa03d6a77c9C,
            yearlyUSDToMonthlyYUSD(84000 * (10**18))
        );
        add_payment(
            targets,
            signatures,
            calldatas,
            0xcc506b3c2967022094C3B00276617883167BF32B,
            yearlyUSDToMonthlyYUSD(30000 * (10**18))
        );
    }

    function add_payment(
        address[] memory targets,
        string[] memory signatures,
        bytes[] memory calldatas,
        address recipient,
        uint256 amount
    ) internal {
        uint256 ctr;
        for (uint256 i = 0; i < targets.length; i++) {
            if (targets[i] != address(0)) {
                ctr++;
            } else {
                break;
            }
        }
        targets[ctr] = address(monthlyAllowance);
        signatures[ctr] = "pay(address,uint256)";
        calldatas[ctr] = abi.encode(recipient, amount);
    }

    function getBOUBalances() internal returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](12);

        balances[0] = yamV3.balanceOfUnderlying(
            0x4a29e88cEA7e1505DB9b6491C749Fb5d6d595265
        );
        balances[1] = yamV3.balanceOfUnderlying(
            0x8A8acf1cEcC4ed6Fe9c408449164CE2034AdC03f
        );
        balances[2] = yamV3.balanceOfUnderlying(
            0xEC3281124d4c2FCA8A88e3076C1E7749CfEcb7F2
        );
        balances[3] = yamV3.balanceOfUnderlying(
            0xC3edCBe0F93a6258c3933e86fFaA3bcF12F8D695
        );
        balances[4] = yamV3.balanceOfUnderlying(
            0xbdac5657eDd13F47C3DD924eAa36Cf1Ec49672cc
        );
        balances[5] = yamV3.balanceOfUnderlying(
            0x01e0C7b70E0E05a06c7cC8deeb97Fa03d6a77c9C
        );
        balances[6] = yamV3.balanceOfUnderlying(
            0xcc506b3c2967022094C3B00276617883167BF32B
        );
        balances[7] = yamV3.balanceOfUnderlying(
            0x386568164bdC5B105a66D8Ae83785D4758939eE6
        );
        balances[8] = yamV3.balanceOfUnderlying(
            0x3FdcED6B5C1f176b543E5E0b841cB7224596C33C
        );
        balances[9] = yamV3.balanceOfUnderlying(
            0x9098eab0a361D29Ea5c4b5d9d1f50694ac0E9e78
        );
        balances[10] = yamV3.balanceOfUnderlying(
            0xf5f1287F7B71381fFB5Caf3b61fA0375112531BC
        );
        balances[11] = yamV3.balanceOfUnderlying(
            0xdADc6F71986643d9e9CB368f08Eb6F1333F6d8f9
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

    function assertOngoingStreams() internal {
        assertStream(
            12,
            0x4a29e88cEA7e1505DB9b6491C749Fb5d6d595265,
            28908000,
            30000 * (10**24) - uint256((30000 * (10**24)) / uint256(12))
        );
        assertStream(
            13,
            0x8A8acf1cEcC4ed6Fe9c408449164CE2034AdC03f,
            28908000,
            25000 * (10**24) - uint256((25000 * (10**24)) / uint256(12))
        );
        assertStream(
            14,
            0xEC3281124d4c2FCA8A88e3076C1E7749CfEcb7F2,
            28908000,
            25000 * (10**24) - uint256((25000 * (10**24)) / uint256(12))
        );
        assertStream(
            15,
            0xC3edCBe0F93a6258c3933e86fFaA3bcF12F8D695,
            28908000,
            30000 * (10**24) - uint256((30000 * (10**24)) / uint256(12))
        );
        assertStream(
            16,
            0xbdac5657eDd13F47C3DD924eAa36Cf1Ec49672cc,
            28908000,
            30000 * (10**24) - uint256((30000 * (10**24)) / uint256(12))
        );
        assertStream(
            17,
            0x01e0C7b70E0E05a06c7cC8deeb97Fa03d6a77c9C,
            28908000,
            25000 * (10**24) - uint256((25000 * (10**24)) / uint256(12))
        );
        assertStream(
            18,
            0xcc506b3c2967022094C3B00276617883167BF32B,
            28908000,
            5000 * (10**24) - uint256((5000 * (10**24)) / uint256(12))
        );
        assertStream(
            19,
            0x386568164bdC5B105a66D8Ae83785D4758939eE6,
            28908000,
            15000 * (10**24) - uint256((15000 * (10**24)) / uint256(12))
        );
        assertStream(
            20,
            0x3FdcED6B5C1f176b543E5E0b841cB7224596C33C,
            28908000,
            15000 * (10**24) - uint256((15000 * (10**24)) / uint256(12))
        );
        assertStream(
            21,
            0x9098eab0a361D29Ea5c4b5d9d1f50694ac0E9e78,
            28908000,
            15000 * (10**24) - uint256((15000 * (10**24)) / uint256(12))
        );
        assertStream(
            22,
            0xf5f1287F7B71381fFB5Caf3b61fA0375112531BC,
            28908000,
            12000 * (10**24) - uint256((12000 * (10**24)) / uint256(12))
        );
        assertStream(
            23,
            0xdADc6F71986643d9e9CB368f08Eb6F1333F6d8f9,
            28908000,
            10000 * (10**24) - uint256((10000 * (10**24)) / uint256(12))
        );
    }

    function assertStream(
        uint256 id,
        address recipient,
        uint256 length,
        uint256 amount
    ) internal {
        address streamRecipient;
        uint128 streamStartTime;
        uint128 streamLength;
        uint256 streamTotalAmount;
        uint256 streamPaidOut;

        (
            streamRecipient,
            streamStartTime,
            streamLength,
            streamTotalAmount,
            streamPaidOut
        ) = vestingPool.streams(id);
        assertEq(streamRecipient, recipient);
        assertEq(uint256(streamLength), length);
        assertEq(streamTotalAmount, amount);
    }
}
