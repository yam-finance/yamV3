pragma solidity 0.5.15;

import "../../lib/SafeERC20.sol";
import "../../lib/SafeMath.sol";
import '../../lib/IUniswapV2Pair.sol';
import "../../lib/UniswapV2OracleLibrary.sol";

interface ExpandedERC20 {
  function decimals() external returns (uint8);
}

contract OTC {

    using SafeMath for uint256;

    /// @notice Address of the approved trader
    address public approved_trader;

    /// @notice Token the reserves are selling
    address public reserves_sell_token;

    /// @notice Token the reserves are puchasing
    address public reserves_purchase_token;

    /// @notice For a sale of a specific amount
    uint256 public sell_amount;

    /// @notice For a purchase of a specific amount
    uint256 public purchase_amount;

    /// @notice Denotes if trade is a sale or purchase
    bool public isSale;

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

    /// @notice Grace period after last twap update for a trade to occur
    uint256 public constant GRACE = 60 * 60; // 1 hour

    /// @notice Uniswap Factory
    address public constant uniFact = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    /// @notice constant used for percentage calculations
    uint256 public constant BASE = 10**18;

    /// @notice Reserve to withdraw from
    address public reserve;

    /// @notice % bound away from TWAP price
    uint256 public twap_bounds;

    /// @notice counts number of twaps
    uint256 public twap_counter;

    /// @notice denotes a trade as complete
    bool public complete;

    /// @notice governor
    address public gov;

    /// @notice pending governor
    address public pendingGov;

    event NewPendingGov(address oldPendingGov, address pendingGov);
    event NewGov(address oldGov, address newGov);
    event SaleSetup(address trader, address reserve, address sellToken, address purchaseToken, uint256 sellAmount);
    event BuySetup(address trader, address reserve, address sellToken, address purchaseToken, uint256 buyAmount);

    modifier onlyGov() {
        require(msg.sender == gov);
        _;
    }

    constructor() public {
      gov = msg.sender;
    }

    function _setPendingGov(address pending)
        public
        onlyGov
    {
        require(pending != address(0));
        address oldPending = pendingGov;
        pendingGov = pending;
        emit NewPendingGov(oldPending, pending);
    }

    function acceptGov()
        public
    {
        require(msg.sender == pendingGov);
        address old = gov;
        gov = pendingGov;
        emit NewGov(old, pendingGov);
    }



    function setup_sale (
        address trader,
        address sell_token,
        address purchase_token,
        uint256 sell_amount_,
        uint256 twap_period,
        uint256 twap_bounds_,
        address uniswap1,
        address uniswap2, // if two hop
        address reserve_
    )
        public
        onlyGov
    {
        approved_trader = trader;
        reserves_sell_token = sell_token;
        reserves_purchase_token = purchase_token;
        sell_amount = sell_amount_;
        reserve = reserve_;
        isSale = true;
        period = twap_period;
        twap_bounds = twap_bounds_;
        complete = false;
        reset_twap(uniswap1, uniswap2, sell_token, purchase_token);
        emit SaleSetup(trader, reserve_, sell_token, purchase_token, sell_amount_);
    }

    function setup_purchase (
        address trader,
        address sell_token,
        address purchase_token,
        uint256 purchase_amount_,
        uint256 twap_period,
        uint256 twap_bounds_,
        address uniswap1,
        address uniswap2, // if two hop
        address reserve_
    )
        public
        onlyGov
    {
        approved_trader = trader;
        reserves_sell_token = sell_token;
        reserves_purchase_token = purchase_token;
        purchase_amount = purchase_amount_;
        reserve = reserve_;
        isSale = false;
        period = twap_period;
        twap_bounds = twap_bounds_;
        complete = false;
        reset_twap(uniswap1, uniswap2, sell_token, purchase_token);
        emit BuySetup(trader, reserve_, sell_token, purchase_token, purchase_amount_);
    }

    function trade (
        uint256 amount_in,
        uint256 amount_out
    )
        public
    {
        require(msg.sender == approved_trader);
        require(recencyCheck(), "TWAP is not recent enough");
        require(!complete, "Trade has already been performed");

        if (isSale) {
            // ensures trader is getting what they expect
            require(sell_amount >= amount_out, "Trader expected out < out");

            // input amount is how many tokens we are buying from desk
            require(withinBounds(amount_in, sell_amount), "Sale price not within bounds of TWAP");

            // transfers input amount of purchase token from trader to reserve
            SafeERC20.safeTransferFrom(IERC20(reserves_purchase_token), approved_trader, reserve, amount_in);

            // transfers set amount of sale token from reserve to trader
            SafeERC20.safeTransferFrom(IERC20(reserves_sell_token), reserve, approved_trader, sell_amount);
        } else {
            // ensures trader is getting what they expect
            require(purchase_amount <= amount_in, "Purchaser expected_in < in");

            // input amount is how many tokens desk is requesting for a given
            // number of tokens
            require(withinBounds(purchase_amount, amount_out), "Purchase price not within bounds of TWAP");

            // transfers set amount of purchase token from trader to reserve
            SafeERC20.safeTransferFrom(IERC20(reserves_purchase_token), approved_trader, reserve, amount_in);

            // transfers requested amount of sale token from reserve to trader
            SafeERC20.safeTransferFrom(IERC20(reserves_sell_token), reserve, approved_trader, amount_out);
        }

        complete = true;
    }

    function recencyCheck()
        internal
        returns (bool)
    {
        return (block.timestamp - blockTimestampLast < GRACE) && (twap_counter > 0);
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
        returns (uint256)
    {
        if (uniswap_pair2 != address(0)) {
            // two hop
            uint256 purchasePrice;
            uint256 salePrice;
            uint256 one;
            if (saleTokenIs0) {
                uint8 decs = ExpandedERC20(reserves_sell_token).decimals();
                require(decs <= 18, "too many decimals");
                one = 10**uint256(decs);
            } else {
                uint8 decs = ExpandedERC20(reserves_sell_token).decimals();
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
                uint8 decs = ExpandedERC20(reserves_sell_token).decimals();
                require(decs <= 18, "too many decimals");
                one = 10**uint256(decs);
            } else {
                uint8 decs = ExpandedERC20(reserves_sell_token).decimals();
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

    function reset_twap(
        address uniswap1,
        address uniswap2,
        address sell_token,
        address purchase_token
    )
        internal
    {
        uniswap_pair1 = uniswap1;
        uniswap_pair2 = uniswap2;

        blockTimestampLast = 0;
        priceCumulativeLastSell = 0;
        priceCumulativeLastBuy = 0;
        priceAverageBuy = 0;

        if (UniswapPair(uniswap1).token0() == sell_token) {
            saleTokenIs0 = true;
        } else {
            saleTokenIs0 = false;
        }

        if (uniswap2 != address(0)) {
            if (UniswapPair(uniswap2).token0() == purchase_token) {
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
      returns (uint256)
    {
      uint256 decs = uint256(ExpandedERC20(reserves_sell_token).decimals());
      uint256 one = 10**decs;
      return purchaseAmount.mul(one).div(saleAmount);
    }

    function bounds()
        public
        returns (uint256)
    {
        uint256 uniswap_quote = consult();
        uint256 minimum = uniswap_quote.mul(BASE.sub(twap_bounds)).div(BASE);
        return minimum;
    }


    function withinBounds (
        uint256 purchaseAmount,
        uint256 saleAmount
    )
        internal
        returns (bool)
    {
        uint256 quoted = quote(purchaseAmount, saleAmount);
        uint256 minimum = bounds();
        return quoted > minimum;
    }
}
