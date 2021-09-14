// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../../lib/YamGoverned.sol";
import "../../lib/TWAPBoundLib.sol";
import "../../lib/IERC20.sol";
import "../../lib/UniRouter2.sol";

// Swapper allows the governor to create swaps
// A swap executes trustlessly and minimizes slippage to a set amount by using TWAPs
// Swaps can be broken up, TWAPs repeatedly updated, etc. 
// Anyone can update TWAPs or execute a swap
contract Swapper is YamSubGoverned, TWAPBoundLib {
    /** Structs */
    struct SwapParams {
        address sourceToken;
        address destinationToken;
        address router;
        address pool1;
        address pool2;
        uint128 sourceAmount;
        uint64 slippageLimit;
    }

    struct SwapState {
        SwapParams params;
        uint256 lastCumulativePriceUpdate;
        uint256 lastCumulativePricePool1;
        uint256 lastCumulativePricePool2;
    }

    /** Constants */
    uint64 private constant MIN_TWAP_TIME = 1 hours;
    uint64 private constant MAX_TWAP_TIME = 3 hours;

    /** State */
    SwapState[] public swaps;

    address public reserves;

    constructor(address _gov, address _reserves) public {
        gov = _gov;
        reserves = _reserves;
    }

    /** Gov functions */
    function addSwap(SwapParams calldata params) external onlyGovOrSubGov {
        swaps.push(
            SwapState({
                params: params,
                lastCumulativePriceUpdate: 0,
                lastCumulativePricePool1: 0,
                lastCumulativePricePool2: 0
            })
        );
    }
 
    function setReserves(address _reserves) external onlyGovOrSubGov {
        reserves = _reserves;
    }
    function removeSwap(uint16 index) external onlyGovOrSubGov {
        _removeSwap(index);
    }

    /** Execution functions */

    function execute(
        uint16 swapId,
        uint128 amountToTrade,
        uint256 minDestinationAmount
    ) external {
        SwapState memory swap = swaps[swapId];
        // Check if there is any left to trade
        require(swap.params.sourceAmount > 0);
        // Can't be trying to trade more than the remaining amount
        require(amountToTrade <= swap.params.sourceAmount);
        uint256 timestamp = block.timestamp;
        uint256 timeSinceLastCumulativePriceUpdate = timestamp -
            swap.lastCumulativePriceUpdate;
        // Require that the cumulative prices were last updated between MIN_TWAP_TIME and MAX_TWAP_TIME
        require(
            timeSinceLastCumulativePriceUpdate >= MIN_TWAP_TIME &&
                timeSinceLastCumulativePriceUpdate <= MAX_TWAP_TIME
        );
        IERC20(swap.params.sourceToken).transferFrom(
            reserves,
            address(this),
            amountToTrade
        );
        if (
            IERC20(swap.params.sourceToken).allowance(
                address(this),
                swap.params.router
            ) < amountToTrade
        ) {
            IERC20(swap.params.sourceToken).approve(
                swap.params.router,
                uint256(-1)
            );
        }
        address[] memory path;
        if (swap.params.pool2 == address(0x0)) {
            path = new address[](2);
            path[0] = swap.params.sourceToken;
            path[1] = swap.params.destinationToken;
        } else {
            address token0 = IUniswapV2Pair(swap.params.pool1).token0();
            path = new address[](3);
            path[0] = swap.params.sourceToken;
            path[1] = token0 == swap.params.sourceToken
                ? IUniswapV2Pair(swap.params.pool1).token1()
                : token0;
            path[2] = swap.params.destinationToken;
        }
        uint256[] memory amounts = UniRouter2(swap.params.router)
            .swapExactTokensForTokens(
                uint256(amountToTrade),
                minDestinationAmount,
                path,
                reserves,
                timestamp
            );

        require(
            TWAPBoundLib.withinBounds(
                IUniswapV2Pair(swap.params.pool1),
                IUniswapV2Pair(swap.params.pool2),
                swap.params.sourceToken,
                swap.params.destinationToken,
                uint256(amountToTrade),
                amounts[amounts.length - 1],
                swap.lastCumulativePricePool1,
                swap.lastCumulativePricePool2,
                timeSinceLastCumulativePriceUpdate,
                swap.params.slippageLimit
            )
        );
        if(amountToTrade == swap.params.sourceAmount){
            _removeSwap(swapId);
        } else {
            swaps[swapId].params.sourceAmount -= amountToTrade;
        }
    }

    function updateCumulativePrice(uint16 swapId) external {
        SwapState memory swap = swaps[swapId];
        uint256 timestamp = block.timestamp;
        require(timestamp - swap.lastCumulativePriceUpdate > MAX_TWAP_TIME);
        (
            swaps[swapId].lastCumulativePricePool1,
            swaps[swapId].lastCumulativePricePool2
        ) = TWAPBoundLib.getCumulativePrices(
            IUniswapV2Pair(swap.params.pool1),
            IUniswapV2Pair(swap.params.pool2),
            swap.params.sourceToken,
            swap.params.destinationToken
        );
        swaps[swapId].lastCumulativePriceUpdate = timestamp;
    }

    /** Internal functions */

    function _removeSwap(uint16 index) internal {
        swaps[index] = SwapState({
            params: SwapParams(
                0x0000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000,
                0,
                0
            ),
            lastCumulativePriceUpdate: 0,
            lastCumulativePricePool1: 0,
            lastCumulativePricePool2: 0
        });
    }
}
