pragma solidity 0.5.15;

import {VestingPool} from "../vesting_pool/VestingPool.sol";
import {
    MonthlyAllowance
} from "../contributor_monthly_payments/MonthlyAllowance.sol";

contract StreamManager {
    VestingPool internal constant pool =
        VestingPool(0xDCf613db29E4d0B35e7e15e93BF6cc6315eB0b82);

    MonthlyAllowance internal constant MONTHLY_ALLOWANCE =
        MonthlyAllowance(0x03A882495Bc616D3a1508211312765904Fb062d1);

    function execute() external {
        // Monthly contributors
        MONTHLY_ALLOWANCE.pay(
            0x8A8acf1cEcC4ed6Fe9c408449164CE2034AdC03f,
            yearlyUSDToMonthlyYUSD(120000 * (10**18))
        );
        MONTHLY_ALLOWANCE.pay(
            0xEC3281124d4c2FCA8A88e3076C1E7749CfEcb7F2,
            yearlyUSDToMonthlyYUSD(105000 * (10**18))
        );
        MONTHLY_ALLOWANCE.pay(
            0xbdac5657eDd13F47C3DD924eAa36Cf1Ec49672cc,
            yearlyUSDToMonthlyYUSD(72000 * (10**18))
        );
        MONTHLY_ALLOWANCE.pay(
            0x01e0C7b70E0E05a06c7cC8deeb97Fa03d6a77c9C,
            yearlyUSDToMonthlyYUSD(84000 * (10**18))
        );
        MONTHLY_ALLOWANCE.pay(
            0xcc506b3c2967022094C3B00276617883167BF32B,
            yearlyUSDToMonthlyYUSD(30000 * (10**18))
        );
        MONTHLY_ALLOWANCE.pay(
            0x3FdcED6B5C1f176b543E5E0b841cB7224596C33C,
            yearlyUSDToMonthlyYUSD(96000 * (10**18))
        );
        MONTHLY_ALLOWANCE.pay(
            0xC45d45b54045074Ed12d1Fe127f714f8aCE46f8c,
            yearlyUSDToMonthlyYUSD(45000 * (10**18))
        );

        // Indigo update
        pool.closeStream(34);
        pool.openStream(
            0xC45d45b54045074Ed12d1Fe127f714f8aCE46f8c,
            90 days,
            560 * 3 * (10**24)
        );

        // Jim update
        pool.closeStream(20);
        pool.openStream(
            0x3FdcED6B5C1f176b543E5E0b841cB7224596C33C,
            90 days,
            1500 * 3 * (10**24)
        );



        // Blokku March backpay and 2 month stream
        pool.payout(
            pool.openStream(
                0x392027fDc620d397cA27F0c1C3dCB592F27A4dc3,
                0,
                200 * (10**24)
            )
        );
        pool.openStream(
            0x392027fDc620d397cA27F0c1C3dCB592F27A4dc3,
            60 days,
            200 * (10**24) * 2
        );

        // Byterose March backpay and 2 month stream
        pool.payout(
            pool.openStream(
                0x0Da87C54F853c2CF1221dbE725018944C83BDA7C,
                0,
                1000 * (10**24)
            )
        );
        pool.openStream(
            0x0Da87C54F853c2CF1221dbE725018944C83BDA7C,
            60 days,
            1000 * (10**24) * 2
        );

        //TheVDM1 open stream
        pool.openStream(
            0xFcB4f3a1710FefA583e7b003F3165f2E142bC725,
            90 days,
            536 * (10**24) * 3
        );

        //Kris update
        pool.closeStream(19);
        pool.openStream(
            0x386568164bdC5B105a66D8Ae83785D4758939eE6,
            90 days,
            264 * (10**24) * 3
        );

        // Ross update
        pool.closeStream(21);
        pool.openStream(
            0x9098eab0a361D29Ea5c4b5d9d1f50694ac0E9e78,
            90 days,
            1594 * (10**24) * 3
        );
        selfdestruct(address(0x0));
    }

    function yearlyUSDToMonthlyYUSD(uint256 yearlyUSD)
        internal
        pure
        returns (uint256)
    {
        // * 100 / 125 accounts for the yUSD price
        return ((yearlyUSD / uint256(12)) * 100) / uint256(125);
    }
}
