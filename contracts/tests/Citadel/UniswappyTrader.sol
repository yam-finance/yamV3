pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import { SafeMath } from "../../lib/SafeMath.sol";
import '../../lib/IUniswapV2Pair.sol';
import "../../lib/IERC20.sol";
import "../../lib/SafeERC20.sol";

interface UniFactory {
    function getPair(address tokenA, address tokenB) external view returns (address);
}

contract UniswappyTrader {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bytes4 constant SwapExactTokensForTokens = bytes4(0x38ed1739);
    bytes4 constant SwapTokensForExactTokens = bytes4(0x199e81ef);
    bytes4 constant Skim = bytes4(keccak256("skim(address,address)"));

    function citadelCall(address sender, bytes memory data) public {
        (
          bytes4 selector,
          uint256 amountA,
          uint256 amountB,
          address[] memory path,
          address to,
          uint256 deadline,
          address factory
        ) = abi.decode(
            data,
            (
                bytes4,
                uint256,
                uint256,
                address[],
                address,
                uint256,
                address
            )
        );

        require(block.timestamp <= deadline, "!deadline");

        if (selector == SwapExactTokensForTokens) {
            _swapExactTokensForTokens(
              amountA,
              amountB,
              path,
              to,
              deadline,
              factory
            );
        } else if (selector == SwapTokensForExactTokens) {
            _swapTokensForExactTokens(
              amountA,
              amountB,
              path,
              to,
              deadline,
              factory
            );
        } else if (selector == Skim) {
            skim(to, sender);
        } else {
            require(false, "!supported trade operation");
        }
    }

    function skim(address token, address to)
        public
    {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > 0){
            IERC20(token).safeTransfer(to, bal);
        }
    }

    function _swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline,
        address factory
    )
        internal
        returns (uint[] memory amounts)
    {
        amounts = getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IERC20(path[0]).safeTransfer(
            _getPair(factory, path[0], path[1]), amounts[0]
        );
        _swap(factory, amounts, path, to);
    }

    function _swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        address to,
        uint256 deadline,
        address factory
    ) internal returns (uint[] memory amounts) {
        amounts = getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        IERC20(path[0]).safeTransfer(
            _getPair(factory, path[0], path[1]), amounts[0]
        );
        _swap(factory, amounts, path, to);
    }

    function _swap(address factory, uint[] memory amounts, address[] memory path, address _to) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = _sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? _getPair(factory, output, path[i + 2]) : _to;
            UniswapPair(_getPair(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function _getPair(
        address factory,
        address tokenA,
        address tokenB
    )
        internal
        view
        returns (address pair)
    {
        return UniFactory(factory).getPair(tokenA, tokenB);
    }

    function getAmountsOut(address factory, uint amountIn, address[] memory path) public view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = _getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = _getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    function getAmountsIn(address factory, uint amountOut, address[] memory path) public view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = _getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = _getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }

    function _getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        address pair = _getPair(factory, tokenA, tokenB);
        (address token0,) = _sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = UniswapPair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    function _getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    function _getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }
}
