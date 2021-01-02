// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;
import {VestingPool} from "../vesting_pool/VestingPool.sol";

contract BulkVestingSetup {
    VestingPool constant VESTING_POOL = VestingPool(
        0xDCf613db29E4d0B35e7e15e93BF6cc6315eB0b82
    );

    function execute() public {
        // Backpay YAM December
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0x4a29e88cEA7e1505DB9b6491C749Fb5d6d595265,
                0,
                uint256((30000 * (10**24)) / uint256(12))
            )
        );
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0x8A8acf1cEcC4ed6Fe9c408449164CE2034AdC03f,
                0,
                uint256((25000 * (10**24)) / uint256(12))
            )
        );
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0xEC3281124d4c2FCA8A88e3076C1E7749CfEcb7F2,
                0,
                uint256((25000 * (10**24)) / uint256(12))
            )
        );
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0xC3edCBe0F93a6258c3933e86fFaA3bcF12F8D695,
                0,
                uint256((30000 * (10**24)) / uint256(12))
            )
        );
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0xbdac5657eDd13F47C3DD924eAa36Cf1Ec49672cc,
                0,
                uint256((30000 * (10**24)) / uint256(12))
            )
        );
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0x01e0C7b70E0E05a06c7cC8deeb97Fa03d6a77c9C,
                0,
                uint256((25000 * (10**24)) / uint256(12))
            )
        );
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0xcc506b3c2967022094C3B00276617883167BF32B,
                0,
                uint256((5000 * (10**24)) / uint256(12))
            )
        );
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0x386568164bdC5B105a66D8Ae83785D4758939eE6,
                0,
                uint256((15000 * (10**24)) / uint256(12))
            )
        );
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0x3FdcED6B5C1f176b543E5E0b841cB7224596C33C,
                0,
                uint256((15000 * (10**24)) / uint256(12))
            )
        );
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0x9098eab0a361D29Ea5c4b5d9d1f50694ac0E9e78,
                0,
                uint256((15000 * (10**24)) / uint256(12))
            )
        );
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0xf5f1287F7B71381fFB5Caf3b61fA0375112531BC,
                0,
                uint256((12000 * (10**24)) / uint256(12))
            )
        );
        VESTING_POOL.payout(
            VESTING_POOL.openStream(
                0xdADc6F71986643d9e9CB368f08Eb6F1333F6d8f9,
                0,
                uint256((10000 * (10**24)) / uint256(12))
            )
        );

        // 11 month ongoing vesting

        VESTING_POOL.openStream(
            0x4a29e88cEA7e1505DB9b6491C749Fb5d6d595265,
            uint128(((1 days * 365) / uint256(12)) * 11),
            30000 * (10**24) - uint256((30000 * (10**24)) / uint256(12))
        );
        VESTING_POOL.openStream(
            0x8A8acf1cEcC4ed6Fe9c408449164CE2034AdC03f,
            uint128(((1 days * 365) / uint256(12)) * 11),
            25000 * (10**24) - uint256((25000 * (10**24)) / uint256(12))
        );
        VESTING_POOL.openStream(
            0xEC3281124d4c2FCA8A88e3076C1E7749CfEcb7F2,
            uint128(((1 days * 365) / uint256(12)) * 11),
            25000 * (10**24) - uint256((25000 * (10**24)) / uint256(12))
        );
        VESTING_POOL.openStream(
            0xC3edCBe0F93a6258c3933e86fFaA3bcF12F8D695,
            uint128(((1 days * 365) / uint256(12)) * 11),
            30000 * (10**24) - uint256((30000 * (10**24)) / uint256(12))
        );
        VESTING_POOL.openStream(
            0xbdac5657eDd13F47C3DD924eAa36Cf1Ec49672cc,
            uint128(((1 days * 365) / uint256(12)) * 11),
            30000 * (10**24) - uint256((30000 * (10**24)) / uint256(12))
        );
        VESTING_POOL.openStream(
            0x01e0C7b70E0E05a06c7cC8deeb97Fa03d6a77c9C,
            uint128(((1 days * 365) / uint256(12)) * 11),
            25000 * (10**24) - uint256((25000 * (10**24)) / uint256(12))
        );
        VESTING_POOL.openStream(
            0xcc506b3c2967022094C3B00276617883167BF32B,
            uint128(((1 days * 365) / uint256(12)) * 11),
            5000 * (10**24) - uint256((5000 * (10**24)) / uint256(12))
        );
        VESTING_POOL.openStream(
            0x386568164bdC5B105a66D8Ae83785D4758939eE6,
            uint128(((1 days * 365) / uint256(12)) * 11),
            15000 * (10**24) - uint256((15000 * (10**24)) / uint256(12))
        );
        VESTING_POOL.openStream(
            0x3FdcED6B5C1f176b543E5E0b841cB7224596C33C,
            uint128(((1 days * 365) / uint256(12)) * 11),
            15000 * (10**24) - uint256((15000 * (10**24)) / uint256(12))
        );
        VESTING_POOL.openStream(
            0x9098eab0a361D29Ea5c4b5d9d1f50694ac0E9e78,
            uint128(((1 days * 365) / uint256(12)) * 11),
            15000 * (10**24) - uint256((15000 * (10**24)) / uint256(12))
        );
        VESTING_POOL.openStream(
            0xf5f1287F7B71381fFB5Caf3b61fA0375112531BC,
            uint128(((1 days * 365) / uint256(12)) * 11),
            12000 * (10**24) - uint256((12000 * (10**24)) / uint256(12))
        );
        VESTING_POOL.openStream(
            0xdADc6F71986643d9e9CB368f08Eb6F1333F6d8f9,
            uint128(((1 days * 365) / uint256(12)) * 11),
            10000 * (10**24) - uint256((10000 * (10**24)) / uint256(12))
        );
        selfdestruct(address(0x0));
    }
}
