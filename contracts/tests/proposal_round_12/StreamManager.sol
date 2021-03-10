pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import {VestingPool} from "../vesting_pool/VestingPool.sol";

contract StreamManager {
    VestingPool internal constant pool =
        VestingPool(0xDCf613db29E4d0B35e7e15e93BF6cc6315eB0b82);

    function execute() external {
        // Ronin update stream
        uint128 startTime;
        uint128 length;
        uint256 totalAmount;
        (, startTime, length, totalAmount, ) = pool.streams(22);
        uint128 currentTime = uint128(block.timestamp);
        uint128 elapsedTime = currentTime - startTime;
        uint128 remainingTime = length - elapsedTime;
        pool.closeStream(22);
        pool.openStream(
            0xf5f1287F7B71381fFB5Caf3b61fA0375112531BC,
            length - elapsedTime,
            (((totalAmount * remainingTime) / length) * 125) / 100
        );

        // Jeremy signing bonus
        pool.payout(pool.openStream(0xeEFA7451c03d52ce909A93654664c46cf81DdD21, 0, 2000 * (10**24)));

        selfdestruct(address(0x0));
    }
}
