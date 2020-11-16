pragma solidity 0.5.15;

import "./YamGoverned.sol";
import "../../lib/SafeERC20.sol";
import "../../lib/SafeMath.sol";
import '../../lib/IUniswapV2Pair.sol';
import "../../lib/UniswapV2OracleLibrary.sol";

interface ExpandedERC20 {
  function decimals() external view returns (uint8);
}

contract TWAPBound is YamSubGoverned {
    using SafeMath for uint256;

    uint256 public constant BASE = 10**18;

    /// @notice For a sale of a specific amount
    uint256 public sell_amount;

    /// @notice For a purchase of a specific amount
    uint256 public purchase_amount;

    /// @notice Token to be sold
    address public sell_token;

    /// @notice Token to be puchased
    address public purchase_token;

    /// @notice Current uniswap pair for purchase & sale tokens
    address public uniswap_pair1;

    /// @notice Second uniswap pair for if TWAP uses two markets to determine price (for liquidity purposes)
    address public uniswap_pair2;

    /// @notice Flag for if purchase token is toke 0 in uniswap pair 2
    bool public purchaseTokenIs0;

    /// @notice Flag for if sale token is token 0 in uniswap pair
    bool public saleTokenIs0;

    /// @notice TWAP for first hop
    uint256 public priceAverageSell;

    /// @notice TWAP for second hop
    uint256 public priceAverageBuy;

    /// @notice last TWAP update time
    uint32 public blockTimestampLast;

    /// @notice last TWAP cumulative price;
    uint256 public priceCumulativeLastSell;

    /// @notice last TWAP cumulative price for two hop pairs;
    uint256 public priceCumulativeLastBuy;

    /// @notice Time between TWAP updates
    uint256 public period;

    /// @notice counts number of twaps
    uint256 public twap_counter;

    /// @notice Grace period after last twap update for a trade to occur
    uint256 public grace = 60 * 60; // 1 hour

    uint256 public constant MAX_BOUND = 10**17;

    /// @notice % bound away from TWAP price
    uint256 public twap_bounds;

    /// @notice denotes a trade as complete
    bool public complete;

    bool public isSale;

    function setup_twap_bound (
        address sell_token_,
        address purchase_token_,
        uint256 amount_,
        bool is_sale,
        uint256 twap_period,
        uint256 twap_bounds_,
        address uniswap1,
        address uniswap2, // if two hop
        uint256 grace_ // length after twap update that it can occur
    )
        public
        onlyGovOrSubGov
    {
        require(twap_bounds_ <= MAX_BOUND, "slippage too high");
        sell_token = sell_token_;
        purchase_token = purchase_token_;
        period = twap_period;
        twap_bounds = twap_bounds_;
        isSale = is_sale;
        if (is_sale) {
            sell_amount = amount_;
            purchase_amount = 0;
        } else {
            purchase_amount = amount_;
            sell_amount = 0;
        }

        complete = false;
        grace = grace_;
        reset_twap(uniswap1, uniswap2, sell_token, purchase_token);
    }

    function reset_twap(
        address uniswap1,
        address uniswap2,
        address sell_token_,
        address purchase_token_
    )
        internal
    {
        uniswap_pair1 = uniswap1;
        uniswap_pair2 = uniswap2;

        blockTimestampLast = 0;
        priceCumulativeLastSell = 0;
        priceCumulativeLastBuy = 0;
        priceAverageBuy = 0;

        if (UniswapPair(uniswap1).token0() == sell_token_) {
            saleTokenIs0 = true;
        } else {
            saleTokenIs0 = false;
        }

        if (uniswap2 != address(0)) {
            if (UniswapPair(uniswap2).token0() == purchase_token_) {
                purchaseTokenIs0 = true;
            } else {
                purchaseTokenIs0 = false;
            }
        }

        update_twap();
        twap_counter = 0;
    }

    function quote(
      uint256 purchaseAmount,
      uint256 saleAmount
    )
      public
      view
      returns (uint256)
    {
      uint256 decs = uint256(ExpandedERC20(sell_token).decimals());
      uint256 one = 10**decs;
      return purchaseAmount.mul(one).div(saleAmount);
    }

    function bounds()
        public
        view
        returns (uint256)
    {
        uint256 uniswap_quote = consult();
        uint256 minimum = uniswap_quote.mul(BASE.sub(twap_bounds)).div(BASE);
        return minimum;
    }

    function bounds_max()
        public
        view
        returns (uint256)
    {
        uint256 uniswap_quote = consult();
        uint256 maximum = uniswap_quote.mul(BASE.add(twap_bounds)).div(BASE);
        return maximum;
    }


    function withinBounds (
        uint256 purchaseAmount,
        uint256 saleAmount
    )
        internal
        view
        returns (bool)
    {
        uint256 quoted = quote(purchaseAmount, saleAmount);
        uint256 minimum = bounds();
        uint256 maximum = bounds_max();
        return quoted > minimum && quoted < maximum;
    }

    function withinBoundsWithQuote (
        uint256 quoted
    )
        internal
        view
        returns (bool)
    {
        uint256 minimum = bounds();
        uint256 maximum = bounds_max();
        return quoted > minimum && quoted < maximum;
    }

    // callable by anyone
    function update_twap()
        public
    {
        (uint256 sell_token_priceCumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(uniswap_pair1, saleTokenIs0);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        // ensure that at least one full period has passed since the last update
        require(timeElapsed >= period, 'OTC: PERIOD_NOT_ELAPSED');

        // overflow is desired
        priceAverageSell = uint256(uint224((sell_token_priceCumulative - priceCumulativeLastSell) / timeElapsed));
        priceCumulativeLastSell = sell_token_priceCumulative;


        if (uniswap_pair2 != address(0)) {
            // two hop
            (uint256 buy_token_priceCumulative, ) =
                UniswapV2OracleLibrary.currentCumulativePrices(uniswap_pair2, !purchaseTokenIs0);
            priceAverageBuy = uint256(uint224((buy_token_priceCumulative - priceCumulativeLastBuy) / timeElapsed));

            priceCumulativeLastBuy = buy_token_priceCumulative;
        }

        twap_counter = twap_counter.add(1);

        blockTimestampLast = blockTimestamp;
    }

    function consult()
        public
        view
        returns (uint256)
    {
        if (uniswap_pair2 != address(0)) {
            // two hop
            uint256 purchasePrice;
            uint256 salePrice;
            uint256 one;
            if (saleTokenIs0) {
                uint8 decs = ExpandedERC20(sell_token).decimals();
                require(decs <= 18, "too many decimals");
                one = 10**uint256(decs);
            } else {
                uint8 decs = ExpandedERC20(sell_token).decimals();
                require(decs <= 18, "too many decimals");
                one = 10**uint256(decs);
            }

            if (priceAverageSell > uint192(-1)) {
               // eat loss of precision
               // effectively: (x / 2**112) * 1e18
               purchasePrice = (priceAverageSell >> 112) * one;
            } else {
              // cant overflow
              // effectively: (x * 1e18 / 2**112)
              purchasePrice = (priceAverageSell * one) >> 112;
            }

            if (purchaseTokenIs0) {
                uint8 decs = ExpandedERC20(UniswapPair(uniswap_pair2).token1()).decimals();
                require(decs <= 18, "too many decimals");
                one = 10**uint256(decs);
            } else {
                uint8 decs = ExpandedERC20(UniswapPair(uniswap_pair2).token0()).decimals();
                require(decs <= 18, "too many decimals");
                one = 10**uint256(decs);
            }

            if (priceAverageBuy > uint192(-1)) {
                salePrice = (priceAverageBuy >> 112) * one;
            } else {
                salePrice = (priceAverageBuy * one) >> 112;
            }

            return purchasePrice.mul(salePrice).div(one);

        } else {
            uint256 one;
            if (saleTokenIs0) {
                uint8 decs = ExpandedERC20(sell_token).decimals();
                require(decs <= 18, "too many decimals");
                one = 10**uint256(decs);
            } else {
                uint8 decs = ExpandedERC20(sell_token).decimals();
                require(decs <= 18, "too many decimals");
                one = 10**uint256(decs);
            }
            // single hop
            uint256 purchasePrice;
            if (priceAverageSell > uint192(-1)) {
               // eat loss of precision
               // effectively: (x / 2**112) * 1e18
               purchasePrice = (priceAverageSell >> 112) * one;
            } else {
                // cant overflow
                // effectively: (x * 1e18 / 2**112)
                purchasePrice = (priceAverageSell * one) >> 112;
            }
            return purchasePrice;
        }
    }

    function recencyCheck()
        internal
        returns (bool)
    {
        return (block.timestamp - blockTimestampLast < grace) && (twap_counter > 0);
    }
}
