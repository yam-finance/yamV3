pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import {VestingPool} from "../../tests/vesting_pool/VestingPool.sol";
import {MonthlyAllowance} from "../../tests/contributor_monthly_payments/MonthlyAllowance.sol";
import {IERC20} from "../../lib/IERC20.sol";
import {IndexStaking2} from "../../tests/index_staking/indexStake.sol";
import {Swapper} from "../../tests/swapper/Swapper.sol";

contract Proposal17 {
    VestingPool internal constant pool =
        VestingPool(0xDCf613db29E4d0B35e7e15e93BF6cc6315eB0b82);

    IERC20 internal constant USDC =
        IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    IERC20 internal constant YAM =
        IERC20(0x0AaCfbeC6a24756c20D41914F2caba817C0d8521);

    IERC20 internal constant INDEX =
        IERC20(0x0954906da0Bf32d5479e25f46056d22f08464cab);

    Swapper internal constant SWAPPER =
        Swapper(0xB4E5BaFf059C5CE3a0EE7ff8e9f16ca9dd91F1fE);

    address internal constant RESERVES =
        0x97990B693835da58A281636296D2Bf02787DEa17;

    IndexStaking2 internal constant INDEX_STAKING =
        IndexStaking2(0x205Cc7463267861002b27021C7108Bc230603d0F);

    function execute() public {
        USDC.transferFrom(
            0x97990B693835da58A281636296D2Bf02787DEa17,
            address(this),
            58250 * (10**6)
        ); // Monthly contributors
        USDC.transfer(
            0x8A8acf1cEcC4ed6Fe9c408449164CE2034AdC03f,
            yearlyUSDToMonthlyUSD(120000 * (10**6))
        );
        USDC.transfer(
            0xEC3281124d4c2FCA8A88e3076C1E7749CfEcb7F2,
            yearlyUSDToMonthlyUSD(105000 * (10**6))
        );
        USDC.transfer(
            0x01e0C7b70E0E05a06c7cC8deeb97Fa03d6a77c9C,
            yearlyUSDToMonthlyUSD(84000 * (10**6))
        );
        USDC.transfer(
            0xcc506b3c2967022094C3B00276617883167BF32B,
            yearlyUSDToMonthlyUSD(30000 * (10**6))
        );
        USDC.transfer(
            0x3FdcED6B5C1f176b543E5E0b841cB7224596C33C,
            yearlyUSDToMonthlyUSD(96000 * (10**6))
        );
        USDC.transfer(
            0x9098eab0a361D29Ea5c4b5d9d1f50694ac0E9e78,
            yearlyUSDToMonthlyUSD(36000 * (10**6))
        );
        USDC.transfer(
            0xFcB4f3a1710FefA583e7b003F3165f2E142bC725,
            yearlyUSDToMonthlyUSD(60000 * (10**6))
        );
        USDC.transfer(
            0x31920DF2b31B5f7ecf65BDb2c497DE31d299d472,
            yearlyUSDToMonthlyUSD(60000 * (10**6))
        );
        USDC.transfer(
            0x43fD74401B4BF04095590a5308B6A5e3Db44b9e3,
            yearlyUSDToMonthlyUSD(48000 * (10**6))
        );
        USDC.transfer(
            0xC45d45b54045074Ed12d1Fe127f714f8aCE46f8c,
            yearlyUSDToMonthlyUSD(60000 * (10**6))
        );

        // YIP-79v2 50k YAM to treasury multisig
        pool.payout(
            pool.openStream(
                0x744D16d200175d20E6D8e5f405AEfB4EB7A962d1,
                0,
                20000 * (10**24)
            )
        );

        // Designer backpay stream
        pool.payout(
            pool.openStream(
                0x3FdcED6B5C1f176b543E5E0b841cB7224596C33C,
                0,
                ((block.timestamp - 1626019344) * 1500 * (10**24)) / (30 days)
            )
        );

        // Designer new stream
        pool.openStream(
            0x3FdcED6B5C1f176b543E5E0b841cB7224596C33C,
            90 days,
            1500 * (10**24) * 3
        );

        // Sushiswap 2 hop SUSHI to ETH to USDC
        SWAPPER.addSwap(
            Swapper.SwapParams({
                sourceToken: 0x6B3595068778DD592e39A122f4f5a5cF09C90fE2,
                destinationToken: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                router: 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F,
                pool1: 0x795065dCc9f64b5614C407a6EFDC400DA6221FB0,
                pool2: 0x397FF1542f962076d0BFE58eA045FfA2d347ACa0,
                sourceAmount: 33733 * (10**18),
                slippageLimit: 1 * (10**16)
            })
        );

        // Uniswap 1 hop WETH to USDC
        SWAPPER.addSwap(
            Swapper.SwapParams({
                sourceToken: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
                destinationToken: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                router: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
                pool1: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                pool2: address(0x0),
                sourceAmount: 120 * (10**18),
                slippageLimit: 1 * (10**16)
            })
        );

        // Uniswap 2 hop INDEX to ETH to USDC
        SWAPPER.addSwap(
            Swapper.SwapParams({
                sourceToken: 0x1494CA1F11D487c2bBe4543E90080AeBa4BA3C2b,
                destinationToken: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                router: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
                pool1: 0x4d5ef58aAc27d99935E5b6B4A6778ff292059991,
                pool2: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                sourceAmount: 928 * (10**18),
                slippageLimit:2 * (10**16)
            })
        );

        INDEX_STAKING._exitAndApproveGetUnderlying();
        INDEX_STAKING._getTokenFromHere(address(INDEX));
        selfdestruct(address(0x0));
    }

    function yearlyUSDToMonthlyUSD(uint256 yearlyUSD)
        internal
        pure
        returns (uint256)
    {
        return ((yearlyUSD / uint256(12)));
    }
}
