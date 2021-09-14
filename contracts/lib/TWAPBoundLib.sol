pragma solidity 0.5.15;

import {IUniswapV2Pair} from "./IUniswapV2Pair.sol";
import {SafeMath} from "./SafeMath.sol";
import {UniswapV2Library} from "./UniswapV2Library.sol";
import {UniswapV2OracleLibrary} from "./UniswapV2OracleLibrary.sol";

contract TWAPBoundLib {
    using SafeMath for uint256;

    uint256 public constant BASE = 10**18;

    function getCurrentDestinationAmount(
        IUniswapV2Pair pool1,
        IUniswapV2Pair pool2,
        address sourceToken,
        address destinationToken,
        uint256 sourceAmount
    ) internal view returns (uint256) {
        bool sourceIsToken0 = pool1.token0() == sourceToken;
        uint256 inReserves;
        uint256 outReserves;
        (inReserves, outReserves, ) = pool1.getReserves();
        uint256 destinationAmount = UniswapV2Library.getAmountOut(
            sourceAmount,
            sourceIsToken0 ? inReserves : outReserves,
            sourceIsToken0 ? outReserves : inReserves
        );
        if (address(pool2) != address(0x0)) {
            bool middleIsToken0 = pool2.token1() == destinationToken;
            (inReserves, outReserves, ) = pool2.getReserves();
            destinationAmount = UniswapV2Library.getAmountOut(
                destinationAmount,
                middleIsToken0 ? inReserves : outReserves,
                middleIsToken0 ? outReserves : inReserves
            );
        }
        return destinationAmount;
    }

    event TestTWAPDestinationAmount(
        uint256 twap,
        uint256 minimum,
        uint256 obtained
    );

    function withinBounds(
        IUniswapV2Pair pool1,
        IUniswapV2Pair pool2,
        address sourceToken,
        address destinationToken,
        uint256 sourceAmount,
        uint256 destinationAmount,
        uint256 lastCumulativePricePool1,
        uint256 lastCumulativePricePool2,
        uint256 timeSinceLastCumulativePriceUpdate,
        uint64 slippageLimit
    ) internal returns (bool) {
        uint256 twapDestinationAmount = getTWAPDestinationAmount(
            pool1,
            pool2,
            sourceToken,
            destinationToken,
            sourceAmount,
            lastCumulativePricePool1,
            lastCumulativePricePool2,
            timeSinceLastCumulativePriceUpdate
        );
        uint256 minimum = twapDestinationAmount.mul(BASE.sub(slippageLimit)).div(
            BASE
        );
        emit TestTWAPDestinationAmount(
            twapDestinationAmount,
            minimum,
            destinationAmount
        );
        return destinationAmount >= minimum;
    }

    // Returns the current cumulative prices for pool1 and pool2. cumulativePricePool2 will be 0 if there is no pool 2
    function getCumulativePrices(
        IUniswapV2Pair pool1,
        IUniswapV2Pair pool2,
        address sourceToken,
        address destinationToken
    )
        internal
        view
        returns (uint256 cumulativePricePool1, uint256 cumulativePricePool2)
    {
        (cumulativePricePool1, ) = UniswapV2OracleLibrary
            .currentCumulativePrices(
                address(pool1),
                pool1.token0() == sourceToken
            );

        if (address(pool2) != address(0x0)) {
            // For when 2 pools are used
            (cumulativePricePool2, ) = UniswapV2OracleLibrary
                .currentCumulativePrices(
                    address(pool2),
                    pool2.token1() == destinationToken
                );
        }
    }

    // Returns the current TWAP
    function getTWAPDestinationAmount(
        IUniswapV2Pair pool1,
        IUniswapV2Pair pool2,
        address sourceToken,
        address destinationToken,
        uint256 sourceAmount,
        uint256 lastCumulativePricePool1,
        uint256 lastCumulativePricePool2,
        uint256 timeSinceLastCumulativePriceUpdate
    ) internal view returns (uint256 price) {
        uint256 cumulativePricePool1;
        uint256 cumulativePricePool2;
        (cumulativePricePool1, cumulativePricePool2) = getCumulativePrices(
            pool1,
            pool2,
            sourceToken,
            destinationToken
        );
        uint256 priceAverageHop1 = uint256(
            uint224(
                (cumulativePricePool1 - lastCumulativePricePool1) /
                    timeSinceLastCumulativePriceUpdate
            )
        );

        if (priceAverageHop1 > uint192(-1)) {
            // eat loss of precision
            // effectively: (x / 2**112) * 1e18
            priceAverageHop1 = (priceAverageHop1 >> 112) * BASE;
        } else {
            // cant overflow
            // effectively: (x * 1e18 / 2**112)
            priceAverageHop1 = (priceAverageHop1 * BASE) >> 112;
        }

        uint256 outputAmount = sourceAmount.mul(priceAverageHop1).div(BASE);

        if (address(pool2) != address(0)) {
            uint256 priceAverageHop2 = uint256(
                uint224(
                    (cumulativePricePool2 - lastCumulativePricePool2) /
                        timeSinceLastCumulativePriceUpdate
                )
            );

            if (priceAverageHop2 > uint192(-1)) {
                // eat loss of precision
                // effectively: (x / 2**112) * 1e18
                priceAverageHop2 = (priceAverageHop2 >> 112) * BASE;
            } else {
                // cant overflow
                // effectively: (x * 1e18 / 2**112)
                priceAverageHop2 = (priceAverageHop2 * BASE) >> 112;
            }

            outputAmount = outputAmount.mul(priceAverageHop2).div(BASE);
        }
        return outputAmount;
    }
}
