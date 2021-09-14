pragma solidity 0.5.15;

import {IERC20} from "../../lib/IERC20.sol";
import {IUniswapV2Pair} from "../../lib/IUniswapV2Pair.sol";
import "../../lib/SafeMath.sol";

/// Helper for a reserve contract to perform uniswap, price bound actions
contract UniHelper {
    using SafeMath for uint256;

    uint256 internal constant ONE = 10**18;

    function _mintLPToken(
        IUniswapV2Pair uniswap_pair,
        IERC20 token0,
        IERC20 token1,
        uint256 amount_token0,
        address token1_source
    ) internal {
        (uint256 reserve0, uint256 reserve1, ) = uniswap_pair.getReserves();
        uint256 quoted = quote(reserve1, reserve0);

        uint256 amount_token1 = quoted.mul(amount_token0).div(ONE);

        token0.transfer(address(uniswap_pair), amount_token0);
        token1.transferFrom(
            token1_source,
            address(uniswap_pair),
            amount_token1
        );
        IUniswapV2Pair(uniswap_pair).mint(address(this));
    }

    function _burnLPToken(IUniswapV2Pair uniswap_pair, address destination)
        internal
    {
        uniswap_pair.transfer(
            address(uniswap_pair),
            uniswap_pair.balanceOf(address(this))
        );
        IUniswapV2Pair(uniswap_pair).burn(destination);
    }

    function quote(uint256 purchaseAmount, uint256 saleAmount)
        internal
        view
        returns (uint256)
    {
        return purchaseAmount.mul(ONE).div(saleAmount);
    }
}
