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

        uint256 bal_of_a = IERC20(sell_token).balanceOf(reserves);
        
        if (amount_ > bal_of_a) {
            // cap to bal
            amount_ = bal_of_a;
        }

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(uniswap_pair1).getReserves();
        uint256 quoted;
        if (saleTokenIs0) {
            quoted = quote(reserve1, reserve0);
            require(withinBoundsWithQuote(quoted), "!in_bounds, uni reserve manipulation");
        } else {
            quoted = quote(reserve0, reserve1);
            require(withinBoundsWithQuote(quoted), "!in_bounds, uni reserve manipulation");
        }

        uint256 amount_b;
        {
          uint256 decs = uint256(ExpandedERC20(sell_token).decimals());
          uint256 one = 10**decs;
          amount_b = quoted.mul(amount_).div(one);
        }


        uint256 bal_of_b = IERC20(purchase_token).balanceOf(reserves);
        if (amount_b > bal_of_b) {
            // we set the limit token as the sale token, but that could change
            // between proposal and execution.
            // limit amount_ and amount_b
            amount_b = bal_of_b;

            // reverse quote
            if (!saleTokenIs0) {
                quoted = quote(reserve1, reserve0);
            } else {
                quoted = quote(reserve0, reserve1);
            }
            // recalculate a
            uint256 decs = uint256(ExpandedERC20(purchase_token).decimals());
            uint256 one = 10**decs;
            amount_ = quoted.mul(amount_b).div(one);
        }

        IERC20(sell_token).transferFrom(reserves, uniswap_pair1, amount_);
        IERC20(purchase_token).transferFrom(reserves, uniswap_pair1, amount_b);
        IUniswapV2Pair(uniswap_pair1).mint(address(this));
        complete = true;
    }

    function _getUnderlyingToken(
        bool skip_this
    )
        internal
    {
        require(!complete, "Action complete");
        require(recencyCheck(), "TWAP needs updating");

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(uniswap_pair1).getReserves();
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
          IUniswapV2Pair(uniswap_pair1).burn(reserves);
        } else {
          IERC20(uniswap_pair1).transfer(uniswap_pair1, IERC20(uniswap_pair1).balanceOf(address(this)));
          IUniswapV2Pair(uniswap_pair1).burn(address(this));
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
