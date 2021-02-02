// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;
import {
    MonthlyAllowance
} from "../contributor_monthly_payments/MonthlyAllowance.sol";
import {VestingPool} from "../vesting_pool/VestingPool.sol";

contract BulkPayer {
    MonthlyAllowance constant MONTHLY_ALLOWANCE = MonthlyAllowance(
        0x03A882495Bc616D3a1508211312765904Fb062d1
    );

    VestingPool constant VESTING_POOL = VestingPool(
        0xDCf613db29E4d0B35e7e15e93BF6cc6315eB0b82
    );

    function execute() public {
        // Backpay YAM December
        MONTHLY_ALLOWANCE.pay(
            0x4a29e88cEA7e1505DB9b6491C749Fb5d6d595265,
            yearlyUSDToMonthlyYUSD(140000 * (10**18))
        );
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
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0x43fD74401B4BF04095590a5308B6A5e3Db44b9e3,
                0,
                134146341463000000000000000
            )
        );
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0x0A1382a504f41BcA6fF1D44b7BDbA06c5Aa3Ca65,
                0,
                182926829268000000000000000
            )
        );
        selfdestruct(address(0x0));
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
