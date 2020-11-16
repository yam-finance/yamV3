pragma solidity 0.5.15;

import "./TWAPBounded.sol";
/// Helper for a reserve contract to perform uniswap, price bound actions
contract ReserveUniHelper is TWAPBound {

    event NewReserves(address oldReserves, address NewReserves);
    
    address public reserves;

    function _getLPToken()
        internal
    {
        require(!complete, "Action complete");

        uint256 amount_;
        if (isSale) {
          amount_ = sell_amount;
        } else {
          amount_ = purchase_amount;
        }
        // early return
        if (amount_ == 0) {
          complete = true;
          return;
        }

        require(recencyCheck(), "TWAP needs updating");


        (uint256 reserve0, uint256 reserve1, ) = UniswapPair(uniswap_pair1).getReserves();
        uint256 quoted;
        if (saleTokenIs0) {
            quoted = quote(reserve1, reserve0);
            require(withinBoundsWithQuote(quoted), "!in_bounds, uni reserve manipulation");
        } else {
            quoted = quote(reserve0, reserve1);
            require(withinBoundsWithQuote(quoted), "!in_bounds, uni reserve manipulation");
        }

        uint256 decs = uint256(ExpandedERC20(sell_token).decimals());
        uint256 one = 10**decs;
        uint256 amount_b = quoted.mul(amount_).div(one);

        IERC20(sell_token).transferFrom(reserves, uniswap_pair1, amount_);
        IERC20(purchase_token).transferFrom(reserves, uniswap_pair1, amount_b);
        UniswapPair(uniswap_pair1).mint(address(this));
        complete = true;
    }

    function _getUnderlyingToken(
        bool skip_this
    )
        internal
    {
        require(!complete, "Action complete");
        require(recencyCheck(), "TWAP needs updating");

        (uint256 reserve0, uint256 reserve1, ) = UniswapPair(uniswap_pair1).getReserves();
        uint256 quoted;
        if (saleTokenIs0) {
            quoted = quote(reserve1, reserve0);
            require(withinBoundsWithQuote(quoted), "!in_bounds, uni reserve manipulation");
        } else {
            quoted = quote(reserve0, reserve1);
            require(withinBoundsWithQuote(quoted), "!in_bounds, uni reserve manipulation");
        }

        // transfer lp tokens back, burn
        if (skip_this) {
          IERC20(uniswap_pair1).transfer(uniswap_pair1, IERC20(uniswap_pair1).balanceOf(address(this)));
          UniswapPair(uniswap_pair1).burn(reserves);
        } else {
          IERC20(uniswap_pair1).transfer(uniswap_pair1, IERC20(uniswap_pair1).balanceOf(address(this)));
          UniswapPair(uniswap_pair1).burn(address(this));
        }
        complete = true;
    }

    function _setReserves(address new_reserves)
        public
        onlyGovOrSubGov
    {
        address old_res = reserves;
        reserves = new_reserves;
        emit NewReserves(old_res, reserves);
    }
}
