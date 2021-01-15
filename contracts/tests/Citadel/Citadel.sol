pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import { SafeMath } from "../../lib/SafeMath.sol";
import "../../lib/IERC20.sol";
import "../../lib/SafeERC20.sol";
import '../../lib/IUniswapV2Pair.sol';
import "../../lib/UniswapV2OracleLibrary.sol";

interface ExpandedERC20 {
  function decimals() external view returns (uint8);
}

contract SafeCast {
    function safe128(uint256 n)
        internal
        pure
        returns (uint128)
    {
        require(n < 2**128, "safe128");
        return uint128(n);
    }

    function safe96(uint256 n)
        internal
        pure
        returns (uint96)
    {
        require(n < 2**96, "safe96");
        return uint96(n);
    }

    function safe32(uint256 n)
        internal
        pure
        returns (uint32)
    {
        require(n < 2**32, "safe32");
        return uint32(n);
    }
}
/**
 * @title MultiInterestRate
 * @author Yam Finance
 *
 * Interest setter that sets interest based on a polynomial of the usage percentage of the market.
 * Interest = C_0 + C_1 * U^(2^0) + C_2 * U^(2^1) + C_3 * U^(2^2) ... C_8 * U^(2^7)
 * i.e.: coefs = [0, 20, 10, 60, 0, 10] = 0 + 20 * util^0 + 10 * util^2 +
 */
contract MultiInterestRate is SafeCast {
    using SafeMath for uint256;

    // ============ Constants ============

    uint128 constant PERCENT = 100;

    uint128 constant BASE = 10 ** 18;

    uint128 constant SECONDS_IN_A_YEAR = 60 * 60 * 24 * 365;

    uint8 constant BYTE = 8;

    // ============ Storage ============

    uint64[] private rate_storage;

    // ============ Constructor ============

    function initialize_rate(
        uint64[] memory coefficients
    )
        internal
    {
        // verify that all coefficients add up to 100%
        for (uint256 i = 0; i < coefficients.length; i++) {
          uint256 sumOfCoefficients = 0;
          for (
              uint256 actual_coefficients = coefficients[i];
              actual_coefficients != 0;
              actual_coefficients >>= BYTE
          ) {
              sumOfCoefficients += actual_coefficients % 256;
          }

          require(
              sumOfCoefficients == PERCENT,
              "must sum to 100"
          );

          // store the params
          rate_storage.push(coefficients[i]);
        }
    }

    // ============ Public Functions ============

    /**
     * Get the interest rate given some utilized and total amounts. The interest function is a
     * polynomial function of the utilization (utilized / total) of the market.
     *
     *   - If both are zero, then the utilization is considered to be equal to 0.
     *
     * @return The interest rate per second (times 10 ** 18)
     */
    function _getInterestRate(
        uint8 marketIndex,
        uint128 utilized,
        uint128 total
    )
        internal
        view
        returns (uint128)
    {
        if (utilized == 0) {
            return 0;
        }
        if (utilized > total) {
            return BASE;
        }

        // process the first coefficient
        uint256 coefficients = rate_storage[marketIndex];
        uint256 result = uint8(coefficients) * BASE;
        coefficients >>= BYTE;

        // initialize polynomial as the utilization
        // no safeDiv since total must be non-zero at this point
        uint256 polynomial = uint256(BASE).mul(utilized) / total;

        // for each non-zero coefficient...
        while (true) {
            // gets the lowest-order byte
            uint256 coefficient = uint256(uint8(coefficients));

            // if non-zero, add to result
            if (coefficient != 0) {
                // no safeAdd since there are at most 16 coefficients
                // no safeMul since (coefficient < 256 && polynomial <= 10**18)
                result += coefficient * polynomial;

                // break if this is the last non-zero coefficient
                if (coefficient == coefficients) {
                    break;
                }
            }

            // double the order of the polynomial term
            // no safeMul since polynomial <= 10^18
            // no safeDiv since the divisor is a non-zero constant
            polynomial = polynomial * polynomial / BASE;

            // move to next coefficient
            coefficients >>= BYTE;
        }

        // normalize the result
        // no safeDiv since the divisor is a non-zero constant
        return uint128(result / (SECONDS_IN_A_YEAR * PERCENT));
    }

    /**
     * Get all of the coefficients of the interest calculation, starting from the coefficient for
     * the first-order utilization variable.
     *
     * @return The coefficients
     */
    function getCoefficients(uint8 marketIndex)
        public
        view
        returns (uint128[] memory)
    {
        // allocate new array with maximum of 16 coefficients
        uint128[] memory result = new uint128[](8);

        // add the coefficients to the array
        uint128 numCoefficients = 0;
        for (
            uint128 coefficients = rate_storage[marketIndex];
            coefficients != 0;
            coefficients >>= BYTE
        ) {
            result[numCoefficients] = coefficients % 256;
            numCoefficients++;
        }

        // modify result.length to match numCoefficients
        assembly {
            mstore(result, numCoefficients)
        }

        return result;
    }
}


contract TWAPPER {
    using SafeMath for uint256;

    /// @notice TWAP for first hop
    uint256[] internal priceAverageSell;

    /// @notice TWAP for second hop
    uint256[] internal priceAverageBuy;

    /// @notice last TWAP update time
    uint32[] internal blockTimestampLast;

    /// @notice last TWAP cumulative price;
    uint256[] internal priceCumulativeLastSell;

    /// @notice last TWAP cumulative price for two hop pairs;
    uint256[] internal priceCumulativeLastBuy;

    /// @notice Time between TWAP updates
    uint256 public period;

    function _update_twap(
        uint8 marketIndex,
        address[] memory path,
        bool[] memory isToken0s
    )
        internal
    {
        (uint256 sell_token_priceCumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(path[0], isToken0s[0]);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast[marketIndex]; // overflow is desired

        // ensure that at least one full period has passed since the last update
        if (timeElapsed < period) {
            return;
        }

        // overflow is desired
        priceAverageSell[marketIndex] = uint256(uint224((sell_token_priceCumulative - priceCumulativeLastSell[marketIndex]) / timeElapsed));
        priceCumulativeLastSell[marketIndex] = sell_token_priceCumulative;


        if (path.length > 1) {
            // two hop
            (uint256 buy_token_priceCumulative, ) =
                UniswapV2OracleLibrary.currentCumulativePrices(path[1], !isToken0s[1]);
            priceAverageBuy[marketIndex] = uint256(uint224((buy_token_priceCumulative - priceCumulativeLastBuy[marketIndex]) / timeElapsed));

            priceCumulativeLastBuy[marketIndex] = buy_token_priceCumulative;
        }

        blockTimestampLast[marketIndex] = blockTimestamp;
    }

    function _consult (
        uint8 marketIndex,
        uint128[] memory path_ones
    )
        internal
        view
        returns (uint256)
    {
        uint256 pas = priceAverageSell[marketIndex];

        if (path_ones.length > 1) {
            // two hop
            uint256 purchasePrice;
            uint256 salePrice;
            uint256 pab = priceAverageBuy[marketIndex];

            if (pas > uint192(-1)) {
               // eat loss of precision
               // effectively: (x / 2**112) * one_token
               purchasePrice = (pas >> 112) * path_ones[0];
            } else {
              // cant overflow
              // effectively: (x * one_token / 2**112)
              purchasePrice = (pas * path_ones[0]) >> 112;
            }

            if (pab > uint192(-1)) {
                salePrice = (pab >> 112) * path_ones[1];
            } else {
                salePrice = (pab * path_ones[1]) >> 112;
            }

            return purchasePrice.mul(salePrice).div(path_ones[1]);
        } else {
            // single hop
            uint256 purchasePrice;
            if (pas > uint192(-1)) {
               // eat loss of precision
               // effectively: (x / 2**112) * one_token
               purchasePrice = (pas >> 112) *  path_ones[0];
            } else {
                // cant overflow
                // effectively: (x * one_token / 2**112)
                purchasePrice = (pas *  path_ones[0]) >> 112;
            }
            return purchasePrice;
        }
    }
}

contract CitadelStorage {

    uint128 public liquidationSpread;
    uint128 public marginRatio;
    uint128 public insuranceRate;
    uint128 public earningsRate;

    bool initialized;
    bool locked;

    Market[] public markets;

    mapping (address => mapping (uint8 => Par)) public accounts;

    // Addresses that can control other users accounts
    mapping (address => mapping (address => bool)) operators;

    struct Par {
        bool sign;
        uint128 value;
    }

    struct Index {
        uint96 borrow;
        uint96 supply;
        uint32 lastUpdate;
    }

    struct Market {
        address token;
        uint96 marginPremium;
        Index index;
        uint128 reserves;
        uint128 utilized;
        uint128 fees;
        uint128 insurance;
        address[] oracle_path;
        uint128[] path_ones;
        bool[] isToken0s;
    }

    struct MarketCache {
        Market market;
        uint256 price;
    }
}

interface Callee {
    function citadelCall(address, bytes calldata) external;
}

contract CitadelLogic is CitadelStorage, MultiInterestRate, TWAPPER {

    using SafeERC20 for IERC20;


    function _accrue(
        uint8 marketIndex
    )
        internal
    {
        require(marketIndex < markets.length, "!market");
        if (markets[marketIndex].index.lastUpdate != safe32(block.timestamp)) {
            uint128 rate = _getInterestRate(marketIndex, markets[marketIndex].utilized, markets[marketIndex].reserves);
            (Index memory newIndex, uint256 withheld) = _calcNewIndex(
                rate,
                markets[marketIndex].index,
                markets[marketIndex].utilized,
                markets[marketIndex].reserves
            );
            markets[marketIndex].index = newIndex;
            uint256 asInsurance = withheld.mul(insuranceRate).div(BASE);
            markets[marketIndex].insurance += safe128(asInsurance);
            markets[marketIndex].fees += safe128(withheld - asInsurance);
        }
    }

    function _deposit(
        uint8 marketIndex,
        address token,
        Index memory index,
        uint256 amount,
        address from,
        address to
    )
        internal
    {
        require(from == msg.sender || from == to, "!deposit source");
        Par memory currPar = accounts[to][marketIndex];
        uint256 deltaPar = _getParFromWei(index, amount, currPar.sign);
        Par memory newPar = add(currPar, deltaPar);
        accounts[to][marketIndex] = newPar;
        IERC20(token).safeTransferFrom(from, address(this), amount);
        _updateMarket(currPar, newPar, marketIndex);
    }

    function _updateMarket(
        Par memory currPar,
        Par memory newPar,
        uint8 marketIndex
    )
        internal
    {
          // roll-back oldPar
          if (currPar.sign) {
              markets[marketIndex].reserves = safe128(uint256(markets[marketIndex].reserves).sub(currPar.value));
          } else {
              markets[marketIndex].utilized = safe128(uint256(markets[marketIndex].utilized).sub(currPar.value));
          }

          // roll-forward newPar
          if (newPar.sign) {
              markets[marketIndex].reserves = safe128(uint256(markets[marketIndex].reserves).add(newPar.value));
          } else {
              markets[marketIndex].utilized = safe128(uint256(markets[marketIndex].utilized).add(newPar.value));
          }
    }

    function _withdraw(
        uint8 marketIndex,
        address token,
        Index memory index,
        uint256 amount,
        address who,
        address to
    )
        internal
    {
        require(to != address(0), "!burning");
        require(_isOperator(who, msg.sender), "!operator");
        Par memory currPar = accounts[who][marketIndex];
        uint256 deltaPar = _getParFromWei(index, amount, currPar.sign);
        Par memory newPar = sub(currPar, deltaPar);
        accounts[who][marketIndex] = newPar;
        IERC20(token).safeTransfer(to, amount);
        _updateMarket(currPar, newPar, marketIndex);
    }

    function _call(
        address who,
        bytes memory data
    )
        internal
    {
        Callee(who).citadelCall(msg.sender, data);
    }

    function _liquidate(
        uint8 marketIndex,
        uint8 secondaryMarketIndex,
        Index memory index,
        Index memory secondaryIndex,
        uint256 amount,
        address who,
        address to
    )
        internal
    {
        require(_isOperator(who, msg.sender), "!operator");

        Par memory liqOwedPar = accounts[to][marketIndex];
        Par memory liqHeldPar = accounts[to][secondaryMarketIndex];

        require(!liqOwedPar.sign, "!owed");
        require(liqHeldPar.sign, "!held");

        // tight scoping
        {
            bool collateralized = _checkCollateralization(to, false);
            require(!collateralized, "!undercollateralized");
        }


        uint256 deltaHeldPar;

        // tight scoping
        {
            uint256 owedPrice = _consult(marketIndex, markets[marketIndex].path_ones);
            // add liquidation spread
            owedPrice = owedPrice.mul(BASE + liquidationSpread);

            uint256 heldPrice = _consult(secondaryMarketIndex, markets[secondaryMarketIndex].path_ones);


            uint256 owedWei = _getWeiFromPar(index, liqOwedPar.value, false);
            // how much held tokens to give back, adjusted for liq spread
            uint256 deltaHeldWei = owedWei.mul(owedPrice).div(heldPrice);

            uint256 maxHeldWei = _getWeiFromPar(secondaryIndex, liqHeldPar.value, true);
            // liquidatee can't fully cover cost of liquidation. bound payback
            if (deltaHeldWei > maxHeldWei) {
                deltaHeldWei = maxHeldWei;
                owedWei = deltaHeldWei.mul(heldPrice).div(owedPrice);
            }

            deltaHeldPar = _getParFromWei(secondaryIndex, deltaHeldWei, true);

            // bound payback amount by owed amount
            if (amount > owedWei) {
               amount = owedWei;
            }
        }

        // tight scoping
        {
            Par memory currPar = accounts[who][marketIndex];
            uint256 deltaPar = _getParFromWei(index, amount, currPar.sign);
            Par memory newPar = sub(currPar, deltaPar);
            accounts[who][marketIndex] = newPar;
            _updateMarket(currPar, newPar, marketIndex);

            newPar = add(liqOwedPar, deltaPar);
            accounts[to][marketIndex] = newPar;
            _updateMarket(liqOwedPar, newPar, marketIndex);

            currPar = accounts[who][secondaryMarketIndex];
            newPar = add(currPar, deltaHeldPar);
            accounts[who][secondaryMarketIndex] = newPar;
            _updateMarket(currPar, newPar, secondaryMarketIndex);


            newPar = sub(liqHeldPar, deltaHeldPar);
            accounts[to][secondaryMarketIndex] = newPar;
            _updateMarket(liqHeldPar, newPar, secondaryMarketIndex);
        }
    }

    function _vaporize(
        Index memory index,
        Index memory secondaryIndex,
        uint256 amount,
        address who,
        address to
    )
        internal
    {
        /* require(_isOperator(who, msg.sender), "!operator");

        bool collateralized = _checkCollateralization(to, false);
        require(!collateralized, "!undercollateralized");

        Par memory currPar = accounts[who][marketIndex];
        uint256 deltaPar = _getParFromWei(index, amount, currPar.sign);
        accounts[who][marketIndex] = sub(currPar, deltaPar);
        IERC20(token).safeTransfer(to, amount); */
    }

    // =========== Helpers ====================
    function _checkCollateralization(
        address who,
        bool required
    )
        internal
        returns (bool)
    {
        uint256 mLen = markets.length;

        // verify account collateralization
        uint256 supplyValue;
        uint256 borrowValue;
        uint32 currTime = safe32(block.timestamp);
        uint128 marginRatio_ = marginRatio;

        for (uint8 j = 0; j < mLen; j++) {
            Par memory acctPar = accounts[who][j];
            if (acctPar.value > 0) {
                uint256 price = _updateAndConsult(j, currTime);
                uint256 adjust = uint256(BASE).add(markets[j].marginPremium);
                if (acctPar.sign) {
                    uint256 asWei = _getWeiFromPar(
                       markets[j].index,
                       acctPar.value,
                       true
                    );
                    supplyValue = supplyValue.add(
                      asWei.mul(price)
                           .mul(adjust)
                           .div(BASE)
                    );
                } else {
                    uint256 asWei = _getWeiFromPar(
                        markets[j].index,
                        acctPar.value,
                        false
                    );
                    borrowValue = borrowValue.add(
                        asWei.mul(price)
                           .mul(BASE)
                           .div(adjust)
                    );
                }
            }
        }

        if (required) {
          if (borrowValue != 0) {
              require(supplyValue >= borrowValue.add(borrowValue.mul(marginRatio_).div(BASE)), "undercollateralized acct");
          } else {
              // happy flashloaning!
          }
        } else {
            return supplyValue >= borrowValue.add(borrowValue.mul(marginRatio_).div(BASE));
        }

    }

    function _hasBalance(
        uint8 marketIndex,
        address who
    )
        internal
        returns (bool)
    {
        return accounts[who][marketIndex].value != 0;
    }

    function _getParFromWei(
        Index memory index,
        uint256 amount,
        bool sign
    )
        internal
        returns (uint256)
    {
        if (sign) {
            return amount.mul(BASE).div(index.supply);
        } else {
            // round up
            if (amount == 0) {
                return 0;
            }
            return amount.mul(BASE).sub(1).div(index.borrow).add(1);
        }
    }

    function _getWeiFromPar(
        Index memory index,
        uint256 amount,
        bool sign
    )
        internal
        returns (uint256)
    {
        if (sign) {
            return amount.mul(index.supply).div(BASE);
        } else {
            // round up
            if (amount == 0) {
                return 0;
            }
            return amount .mul(index.borrow).sub(1).div(BASE).add(1);
        }
    }

    function _isOperator(
        address who,
        address maybeOp
    )
        internal
        returns (bool)
    {
        return who == maybeOp || operators[who][maybeOp];
    }

    function _calcNewIndex(
        uint256 ratePerSecond,
        Index memory index,
        uint256 borrowed,
        uint256 supplied
    )
        internal
        returns (Index memory, uint256)
    {
        uint96 newBI;
        uint96 newSI;
        // get interest increase for borrowers
        uint32 currentTime = safe32(block.timestamp);
        uint256 withheld;
        {
          uint256 borrowInterest = ratePerSecond.mul(uint256(currentTime).sub(index.lastUpdate));
          {
              uint128 bi = index.borrow;
              newBI = safe96(uint256(bi).mul(borrowInterest).div(BASE).add(bi));
          }

          uint256 supplyInterest;
          {
              uint256 suppliedWei = _getWeiFromPar(index, supplied, true);
              if (suppliedWei == 0) {
                 supplyInterest = 0;
              } else {
                 supplyInterest = borrowInterest.mul(earningsRate).div(BASE);
                 withheld = borrowInterest - supplyInterest;

                 uint256 borrowedWei = _getWeiFromPar(index, borrowed, false);
                 if (borrowedWei < suppliedWei) {
                     supplyInterest = supplyInterest.mul(borrowedWei).div(suppliedWei);
                 }
              }
          }

          assert(supplyInterest <= borrowInterest);
          {
              uint128 si = index.supply;
              newSI = safe96(uint256(si).mul(supplyInterest).div(BASE).add(si));
          }
        }

        return (
            Index({
               borrow: newBI,
               supply: newSI,
               lastUpdate: currentTime
            }),
            withheld
        );
    }

    function _getMarketPrice(
        uint8 marketIndex
    )
        internal
        view
        returns (uint256)
    {
        return _consult(marketIndex, markets[marketIndex].path_ones);
    }

    function _updateAndConsult(
        uint8 marketIndex,
        uint32 time
    )
        internal
        returns (uint256)
    {
        uint32 timeElapsed = time - blockTimestampLast[marketIndex]; // overflow is desired

        // ensure that at least one full period has passed since the last update
        if (timeElapsed >= period) {
            _update_twap(
                marketIndex,
                markets[marketIndex].oracle_path,
                markets[marketIndex].isToken0s
            );
        }

        return _consult(marketIndex, markets[marketIndex].path_ones);
    }

    function add(
        Par memory a,
        uint256 b
    )
        internal
        pure
        returns (Par memory)
    {
        Par memory result;
        if (a.sign) {
            result.sign = true;
            result.value = safe128(SafeMath.add(a.value, b));
        } else {
            if (a.value >= b) {
                result.value = safe128(SafeMath.sub(a.value, b));
            } else {
                result.sign = true;
                result.value = safe128(SafeMath.sub(b, a.value));
            }
        }
        return result;
    }

    function sub(
        Par memory a,
        uint256 b
    )
        internal
        pure
        returns (Par memory)
    {
        Par memory result;
        if (a.sign) {
            if (a.value >= b) {
                result.sign = true;
                result.value = safe128(SafeMath.sub(a.value, b));
            } else {
                result.value = safe128(SafeMath.sub(b, a.value));
            }
        } else {
            result.value = safe128(SafeMath.add(a.value, b));
        }
        return result;
    }
}

contract CitadelLending is CitadelLogic {
    // =========== Modifiers ====================
    modifier lock() {
        require(locked == false, "locked");
        locked = true;
        _;
        locked = false;
    }

    // =========== Data Structures ==============
    enum Op {
        Deposit,
        Withdraw,
        Call,
        Liquidate,
        Vaporize
    }

    struct AnyArg {
        // what operation?
        Op op;
        // market index
        uint8 marketIndex;
        // secondary market index for liquidation & vaporize
        uint8 secondaryMarketIndex;
        // index of the address list to reference
        uint8 fromIndex;
        // index of the address list to reference
        uint8 toIndex;
        // For anything needing an amount
        uint256 amount;
        // For calls/flashloans
        address externalAddress;
        bytes data;
    }

    // =========== Constructor =================
    function initialize(
        address[] memory tokens,
        address denominatingToken,
        address[][] memory oracle_paths,
        uint64[] memory coefficients,
        uint256[] memory marginPremiums,
        uint128 insuranceRate_,
        uint128 earningsRate_,
        uint128 marginRatio_,
        uint32 period_
    )
        public
    {
        require(!initialized, "initialized");
        require(tokens.length == oracle_paths.length, "!len parity");
        require(tokens.length == coefficients.length, "!len parity2");

        initialize_rate(coefficients);

        insuranceRate = insuranceRate_;
        earningsRate = earningsRate_;
        marginRatio = marginRatio_;
        period = period_;

        priceAverageSell = new uint256[](tokens.length);
        priceAverageBuy = new uint256[](tokens.length);
        blockTimestampLast = new uint32[](tokens.length);
        priceCumulativeLastSell = new uint256[](tokens.length);
        priceCumulativeLastBuy = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            // fill path_ones and token0s
            uint128[] memory path_ones = new uint128[](oracle_paths[i].length);
            path_ones[0] = safe128(10**uint256(ExpandedERC20(tokens[i]).decimals()));

            bool[] memory token0s = new bool[](oracle_paths[i].length);
            token0s[0] = tokens[i] == UniswapPair(oracle_paths[i][0]).token0();

            if (oracle_paths[i].length > 1) {
                // two hop twap
                address token0 = UniswapPair(oracle_paths[i][1]).token0();
                // set isToken0
                token0s[1] = denominatingToken == token0;
                if (!token0s[1]) {
                  // set path_ones
                  path_ones[1] = safe128(10**uint256(ExpandedERC20(token0).decimals()));
                  // ensure same denomination
                  require(denominatingToken == UniswapPair(oracle_paths[i][1]).token1(), "inconsistent denomination");
                } else {
                  // set path_ones
                  path_ones[1] = safe128(10**uint256(ExpandedERC20(UniswapPair(oracle_paths[i][1]).token1()).decimals()));
                }
            } else {
              // ensure same denomination
              if (token0s[0]) {
                require(denominatingToken == UniswapPair(oracle_paths[i][0]).token1(), "inconsistent denomination");
              } else {
                require(denominatingToken == UniswapPair(oracle_paths[i][0]).token0(), "inconsistent denomination");
              }
            }

            markets.push(Market({
                token: tokens[i],
                marginPremium: safe96(marginPremiums[i]),
                index: Index({borrow: safe96(10**18), supply: safe96(10**18), lastUpdate: safe32(block.timestamp)}),
                reserves: 0,
                utilized: 0,
                fees: 0,
                insurance: 0,
                oracle_path: oracle_paths[i],
                path_ones: path_ones,
                isToken0s: token0s
            }));

            _update_twap(
                uint8(i),
                oracle_paths[i],
                token0s
            );
        }

    }

    // =========== Getters =================
    function getMarketIndex(
        address token
    )
        public
        view
        returns (uint8)
    {
        for (uint8 i = 0; i < markets.length; i++) {
            if (markets[i].token == token) {
                return i;
            }
        }
        require(false, "No Market");
    }

    function getMarketPrice(
        uint8 marketIndex
    )
        public
        view
        returns (uint256)
    {
        return _getMarketPrice(marketIndex);
    }

    function getMarketInfo(
        uint8 marketIndex
    )
        public
        view
        returns (Market memory)
    {
        Market memory market = markets[marketIndex];
        return market;
    }

    // =========== Actions =================
    function refresh_price(
        uint8 marketIndex
    )
        public
    {
        _update_twap(
            marketIndex,
            markets[marketIndex].oracle_path,
            markets[marketIndex].isToken0s
        );
    }

    function deposit(
        uint8 marketIndex,
        uint256 amount
    )
        public
        lock
    {
        _accrue(marketIndex);
        _deposit(marketIndex, markets[marketIndex].token, markets[marketIndex].index, amount, msg.sender, msg.sender);
        // a deposit can never undercollateralize an account thus no need to check
    }

    function depositTo(
        uint8 marketIndex,
        uint256 amount,
        address to
    )
        public
        lock
    {
        _accrue(marketIndex);
        _deposit(marketIndex, markets[marketIndex].token, markets[marketIndex].index, amount, msg.sender, to);
        // a deposit can never undercollateralize an account thus no need to check
    }

    function withdraw(
        uint8 marketIndex,
        uint256 amount
    )
        public
        lock
    {
        _accrue(marketIndex);
        _withdraw(marketIndex, markets[marketIndex].token, markets[marketIndex].index, amount, msg.sender, msg.sender);
        _checkCollateralization(msg.sender, true);
    }

    function withdrawFrom(
        uint8 marketIndex,
        uint256 amount,
        address who,
        address to
    )
        public
        lock
    {
        _accrue(marketIndex);
        _withdraw(marketIndex, markets[marketIndex].token, markets[marketIndex].index, amount, who, to);
        _checkCollateralization(who, true);
    }

    function liquidate(
        uint8 marketIndex,
        uint8 secondaryMarketIndex,
        uint256 amount,
        address who,
        address to
    )
        public
        lock
    {
        _accrue(marketIndex);
        _accrue(secondaryMarketIndex);
        _liquidate(marketIndex, secondaryMarketIndex, markets[marketIndex].index, markets[secondaryMarketIndex].index, amount, who, to);
        _checkCollateralization(who, true);
    }

    function operate(
        address[] memory whos,
        AnyArg[] memory ops
    )
        public
        lock
    {
        uint32 currTime = safe32(block.timestamp);
        for (uint256 a = 0; a < whos.length; a++) {
            // check no duplicate
            for (uint256 b = a + 1; b < whos.length; b++) {
                require(whos[a] != whos[b], "Cannot duplicate accounts");
            }

            // accrue interest, load cache
            for (uint8 j = 0; j < markets.length; j++) {
                if (_hasBalance(j, whos[a])) {
                    _accrue(j);
                }
            }
        }

        uint8 opLen = uint8(ops.length);
        bool[] memory primaryAccounts = new bool[](whos.length);

        for (uint256 i = 0; i < opLen; i++) {
            AnyArg memory op = ops[i];
            if (op.op == Op.Call) {
                _call(op.externalAddress, op.data);
            } else {
                _accrue(op.marketIndex);
                if (op.op == Op.Deposit) {
                    _deposit(op.marketIndex, markets[op.marketIndex].token, markets[op.marketIndex].index, op.amount, op.externalAddress, whos[op.toIndex]);
                } else if (op.op == Op.Withdraw) {
                    primaryAccounts[op.fromIndex] = true;
                    _withdraw(op.marketIndex, markets[op.marketIndex].token, markets[op.marketIndex].index, op.amount, whos[op.fromIndex], op.externalAddress);
                } else {
                    primaryAccounts[op.fromIndex] = true;
                    _accrue(op.secondaryMarketIndex);
                    if (op.op == Op.Liquidate) {
                      _liquidate(op.marketIndex, op.secondaryMarketIndex, markets[op.marketIndex].index, markets[op.secondaryMarketIndex].index, op.amount, whos[op.fromIndex], whos[op.toIndex]);
                    } else {
                      require(op.op == Op.Vaporize, "not an op");
                      _vaporize(markets[op.marketIndex].index, markets[op.secondaryMarketIndex].index, op.amount, whos[op.fromIndex], whos[op.toIndex]);
                    }
                }
            }
        }

        for (uint256 i = 0; i < whos.length; i++) {
            if (primaryAccounts[i]) {
                _checkCollateralization(whos[i], true);
            }
        }
    }
}
