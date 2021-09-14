pragma solidity 0.5.15;

import {IERC20} from "../../lib/IERC20.sol";
import {IUniswapV2Pair} from "../../lib/IUniswapV2Pair.sol";
import "../../lib/SafeMath.sol";

/// Helper for a reserve contract to perform uniswap, price bound actions
contract UniHelper{
    using SafeMath for uint256;

    uint256 internal constant ONE = 10**18;

    function _mintLPToken(
        IUniswapV2Pair uniswap_pair,
        IERC20 token0,
        IERC20 token1,
        uint256 amount_token1,
        address token0_source
    ) internal {
        (uint256 reserve0, uint256 reserve1, ) = uniswap_pair
            .getReserves();
        uint256 quoted = quote(reserve0, reserve1);

        uint256 amount_token0 = quoted.mul(amount_token1).div(ONE);

        token0.transferFrom(token0_source, address(uniswap_pair), amount_token0);
        token1.transfer(address(uniswap_pair), amount_token1);
        IUniswapV2Pair(uniswap_pair).mint(address(this));
    }

    function _burnLPToken(IUniswapV2Pair uniswap_pair, address destination) internal {
        uniswap_pair.transfer(
            address(uniswap_pair),
            uniswap_pair.balanceOf(address(this))
        );
        IUniswapV2Pair(uniswap_pair).burn(destination);
    }

    function quote(uint256 purchaseAmount, uint256 saleAmount)
        internal
        pure
        returns (uint256)
    {
        return purchaseAmount.mul(ONE).div(saleAmount);
    }

}
