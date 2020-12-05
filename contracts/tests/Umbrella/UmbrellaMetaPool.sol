pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import { SafeMath } from "../../lib/SafeMath.sol";
import { SafeMath128 } from "../../lib/SafeMath128.sol";
import { WETH9 } from "../../lib/WETH9.sol";
import "../../lib/IERC20.sol";
import "../../lib/SafeERC20.sol";


interface ExpandedERC20 {
  function decimals() external returns (uint8);
}


/**
 * @title CoverRate
 * @author Yam Finance
 *
 * Interest setter that sets interest based on a polynomial of the usage percentage of the market.
 * Interest = C_0 + C_1 * U^(2^0) + C_2 * U^(2^1) + C_3 * U^(2^2) ... C_8 * U^(2^7)
 * i.e.: coefs = [0, 20, 10, 60, 0, 10] = 0 + 20 * util^0 + 10 * util^2 +
 */
contract CoverRate {
    using SafeMath for uint256;
    using SafeMath128 for uint128;

    // ============ Constants ============

    uint128 constant PERCENT = 100;

    uint128 constant BASE = 10 ** 18;

    uint128 constant SECONDS_IN_A_YEAR = 60 * 60 * 24 * 365;

    uint128 constant BYTE = 8;

    // ============ Storage ============

    uint64 rate_storage;

    // ============ Constructor ============

    function intialize_rate(
        uint64 coefficients
    )
        internal
    {
        // verify that all coefficients add up to 100%
        uint256 sumOfCoefficients = 0;
        for (
            uint256 actual_coefficients = coefficients;
            actual_coefficients != 0;
            actual_coefficients >>= BYTE
        ) {
            sumOfCoefficients += actual_coefficients % 256;
        }
        require(
            sumOfCoefficients == PERCENT,
            "Coefficients must sum to 100"
        );

        // store the params
        rate_storage = coefficients;
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
    function getInterestRate(
        uint128 utilized,
        uint128 total
    )
        public
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
        uint256 coefficients = rate_storage;
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
    function getCoefficients()
        public
        view
        returns (uint128[] memory)
    {
        // allocate new array with maximum of 16 coefficients
        uint128[] memory result = new uint128[](8);

        // add the coefficients to the array
        uint128 numCoefficients = 0;
        for (
            uint128 coefficients = rate_storage;
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


contract CoverPricing is CoverRate {
    using SafeMath128 for uint128;

    // ============ Functions ============

    /// @notice Price a given
    function price(uint128 coverageAmount, uint128 duration, uint128 utilized, uint128 reserves)
        public
        view
        returns (uint128)
    {
        return _price(coverageAmount, duration, utilized, reserves);
    }


    function _price(uint128 coverageAmount, uint128 duration, uint128 utilized, uint128 reserves)
        internal
        view
        returns (uint128)
    {
        require(duration <= SECONDS_IN_A_YEAR, "ProtectionPool::_price: duration > max duration");
        uint128 new_util = utilized.add(coverageAmount);
        uint128 rate = getInterestRate(new_util, reserves);

        // price = amount * rate_per_second * duration / 10**18
        uint128 coverage_price = uint128(uint256(coverageAmount).mul(rate).mul(duration).div(BASE));

        return coverage_price;
    }
}

interface ERC721TokenReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    )
        external
        returns(bytes4);
}

contract UmbrellaMetaPool is CoverPricing {
    using SafeMath128 for uint128;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @dev Emitted when creating a new protection
    event NewProtection(string indexed concept, uint128 amount, uint32 duration, uint128 coverage_price);
    /// @dev Emitted when adding to reserves
    event ProvideCoverage(address indexed provider, uint128 amount);
    /// @dev Emitted when Arbiter is paid
    event ArbiterPaid(uint256 amount);
    /// @dev Emitted when Creator is paid
    event CreatorPaid(uint256 amount);
    /// @dev Emitted when withdrawing provided payTokens
    event Withdraw(address indexed provider, uint256 amount);
    /// @dev Emitted when transfering a token
    event Claim(address indexed holder, uint256 indexed pid, uint256 payout);
    /// @dev Emitted when transfering a token
    event ClaimPremiums(address indexed claimer, uint256 premiums_claimed);
    /// @dev Emitted when transfering a token
    event Swept(uint256 indexed pid, uint128 premiums_paid);
    /// @dev Emitted when transfering a token
    event Transfer(address indexed from, address indexed to, uint256 indexed pid);
    /// @dev Emitted when adding an operator
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    // ============ Modifiers ============

    modifier hasArbiter() {
        require(arbSet, "ProtectionPool::hasArbiter: !arbiter");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "ProtectionPool::onlyArbiter: !arbiter");
        _;
    }

    modifier updateTokenSecondsProvided(address account) {
      uint256 timestamp = block.timestamp;
      uint256 newTokenSecondsProvided = (timestamp - providers[account].lastUpdate).mul(providers[account].curTokens);

      // update user protection seconds, and last updated
      providers[account].totalTokenSecondsProvided = providers[account].totalTokenSecondsProvided.add(newTokenSecondsProvided);
      providers[account].lastUpdate = safe32(timestamp);

      // increase total protection seconds
      uint256 newGlobalTokenSecondsProvided = (timestamp - lastUpdatedTPS).mul(reserves);
      totalProtectionSeconds = totalProtectionSeconds.add(newGlobalTokenSecondsProvided);
      lastUpdatedTPS = safe32(timestamp);
      _;
    }

    // ============ Constants ============

    // TODO: Move to factory
    /// @notice Max arbiter fee, 10%.
    uint128 public constant MAX_ARB_FEE = 10**17;
    /// @notice Max creator fee, 5%.
    uint128 public constant MAX_CREATE_FEE = 5*10**16;
    /// @notice ALPHA USE ONLY, PLACES CAP ON TVL
    uint128 public constant MAX_RESERVES = 1000 * 10**18;
    // :TODO

    /// @notice How long a pool is settleable for, afterword enters cooldown
    uint128 public constant SETTLE_LENGTH = 60 * 60 * 24 * 14;
    /// @notice How long a pool is in cooldown for, after a settlement. Unclaimed protection becomes sweepable
    uint128 public constant COOLDOWN_LENGTH = 60 * 60 * 24 * 7;


    /// @notice How long liquidity is locked up (7 days)
    uint128 public constant LOCKUP_PERIOD = 60 * 60 * 24 * 7;
    /// @notice How long a withdrawl request is valid for (2 weeks)
    uint128 public constant WITHDRAW_GRACE_PERIOD = 60 * 60 * 24 * 14;

    /// @notice WETH address
    WETH9 public constant WETH = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // ============ Storage ============
    /// @notice Whether the pool has been initialized
    bool public initialized;
    /// @notice Whether the pool has an arbiter
    bool public arbSet;
    bool public accepted;

    // === Pool storage ===
    /// @notice List of protected concepts, i.e. ["Dydx", "Compound", "Aave"]
    string[] public coveredConcepts;
    /// @notice Description of the pool; i.e. yEarn yVaults
    string public description;
    /// @notice Token used for protection payment and payout
    address public payToken;
    /// @notice utilized payToken
    uint128 public utilized;
    /// @notice total payToken
    uint128 public reserves;
    /// @notice Minimum number of payTokens to open a position
    uint128 public minPay;
    /// @notice Factory used to create this contract
    address public factory;
    /// @notice Last global update to protection seconds
    uint32 public lastUpdatedTPS;
    /// @notice Total global protection seconds
    uint256 public totalProtectionSeconds;
    ///@notice Total premiums accumulated
    uint256 public premiumsAccum;

    // === Creator storage ===
    /// @notice Creator fee
    uint128 public creatorFee;
    /// @notice Accumulated Creator Fee
    uint128 public creatorFees;
    /// @notice Address that is the creator of the pool
    address public creator;

    // === Arbiter storage ===
    /// @notice Arbiter Fee
    uint128 public arbiterFee;
    /// @notice Accumulated Arbiter Fee
    uint128 public arbiterFees;
    /// @notice Address that is the arbiter over the pool
    address public arbiter;

    // === Rollover storage ===
    /// @notice % of premiums rolled into provided coverage
    uint128 public rollover;

    // === Concept status storage ===
    /// @notice Array of protections
    Protection[] public protections;
    /// @notice State of the concept market status
    ConceptStatus[] public conceptStatuses;

    /// @notice Claim times for concepts
    uint32[] public claimTimes;
    ///@notice Array of settlement start times
    uint32[] public settleStart;
    ///@notice Array of cooldown start times
    uint32[] public cooldownStart;

    // === Token storage ===
    /// @notice allow operators
    mapping ( address => mapping ( address => bool )) public operators;

    ///@notice Provider mapping
    mapping ( address => ProtectionProvider ) public providers;

    // ============ Structs & Enums ============
    enum Status { Active, Swept, Claimed }
    enum ConceptStatus { Active, Settling, Cooldown }


    struct ProtectionProvider {
      uint256 totalTokenSecondsProvided;
      uint256 claimed;
      uint128 curTokens;
      uint32 lastUpdate;
      uint32 lastProvide;
      uint32 withdrawInitiated;
    }

    struct Protection {
        // slot 1
        uint128 coverageAmount;
        uint128 paid;
        // slot 2
        address holder;
        uint32 start;
        uint32 expiry;
        uint8 conceptIndex;
        Status status;
    }

    // ============ Constructor ============

    function initialize(
        address payToken_,
        uint64 coefficients,
        uint128 creatorFee_,
        uint128 arbiterFee_,
        uint128 rollover_,
        uint128 minPay_,
        string[] memory coveredConcepts_,
        string memory description_,
        address creator_,
        address arbiter_
    )
        public
    {
        require(!initialized, "initialized");
        initialized = true;
        require(coveredConcepts_.length < 16, "too many concepts");

        // TODO: Move to factory
        require(arbiterFee_ <= MAX_ARB_FEE, "!arb fee");
        require(creatorFee_ <= MAX_CREATE_FEE, "!create fee");
        // :TODO

        intialize_rate(coefficients);

        payToken         = payToken_;
        arbiterFee       = arbiterFee_;
        creatorFee       = creatorFee_;
        rollover         = rollover_;
        coveredConcepts  = coveredConcepts_;
        description      = description_;
        creator          = creator_;
        arbiter          = arbiter_;
        minPay           = minPay_;

        conceptStatuses = new ConceptStatus[](coveredConcepts_.length);
        claimTimes      = new uint32[](coveredConcepts_.length);
        settleStart     = new uint32[](coveredConcepts_.length);
        cooldownStart   = new uint32[](coveredConcepts_.length);

        if (creator_ == arbiter_) {
            // auto accept if creator is arbiter
            arbSet = true;
            accepted = true;
        }
    }

    // ============ View Functions ============

    function getConcepts()
        public
        view
        returns (string[] memory)
    {
        string[] memory concepts = coveredConcepts;
        return concepts;
    }

    function getConceptIndex(string memory concept)
        public
        view
        returns (uint256)
    {
        for (uint8 i = 0; i < coveredConcepts.length; i++) {
          if (keccak256(abi.encodePacked(coveredConcepts[i])) == keccak256(abi.encodePacked(concept))) {
            return i;
          }
        }
        require(false, "!concept");
    }

    function conceptEnterable(uint8 conceptIndex)
        public
        view
        returns (bool)
    {
        return conceptStatuses[conceptIndex] == ConceptStatus.Active;
    }

    function getProtectionInfo(uint256 pid)
        public
        view
        returns (Protection memory)
    {
        return protections[pid];
    }

    /// @notice Current coverage provider total protection seconds
    function currentProviderTPS(address who)
        public
        view
        returns (uint256)
    {
        uint256 timestamp = block.timestamp;
        uint256 newTokenSecondsProvided = (timestamp - providers[who].lastUpdate).mul(providers[who].curTokens);
        return providers[who].totalTokenSecondsProvided.add(newTokenSecondsProvided);
    }


    // ============ Modifying Protection Buyer Functions ============

    /// @notice Purchase protection
    /// @dev accepts ETH payment if payToken is WETH
    function buyProtection(
        uint8 conceptIndex,
        uint128 coverageAmount,
        uint128 duration,
        uint128 maxPay,
        uint256 deadline
    )
        public
        payable
        hasArbiter
    {
        // check deadline
        require(block.timestamp <= deadline,               "ProtectionPool::buyProtection: !deadline");
        require(   conceptIndex <  coveredConcepts.length, "ProtectionPool::buyProtection: !conceptIndex");
        require(conceptEnterable(conceptIndex),            "ProtectionPool::buyProtection: !conceptEnterable");

        // price coverage
        uint128 coverage_price = _price(coverageAmount, duration, utilized, reserves);

        // check payment
        require(utilized.add(coverageAmount) <= reserves, "ProtectionPool::buyProtection: overutilized");
        require(              coverage_price >= minPay,   "ProtectionPool::buyProtection: price < minPay");
        require(              coverage_price <= maxPay,   "ProtectionPool::buyProtection: too expensive");

        // push protection onto array
        // protection buying stops in year 2106 due to safe cast
        protections.push(
          Protection({
              coverageAmount: coverageAmount,
              paid: coverage_price,
              holder: msg.sender,
              start: safe32(block.timestamp),
              expiry: safe32(block.timestamp + duration),
              conceptIndex: conceptIndex,
              status: Status.Active
          })
        );

        // increase utilized
        utilized = utilized.add(coverageAmount);

        if (payToken == address(WETH) && msg.value > 0) {
            // wrap eth => WETH if necessary
            uint256 remainder = msg.value.sub(coverage_price, "ProtectionPool::buyProtection: underpayment");
            WETH.deposit.value(coverage_price)();

            // send back excess, 2300 gas
            if (remainder > 0) {
                msg.sender.transfer(remainder);
            }
        } else {
            require(msg.value == 0, "ProtectionPool::buyProtection: payToken !WETH, dont send eth");
            IERC20(payToken).safeTransferFrom(msg.sender, address(this), coverage_price);
        }

        // events
        emit NewProtection(coveredConcepts[conceptIndex], coverageAmount, safe32(duration), coverage_price);
    }

    function claim(uint256 pid)
        public
    {
        Protection storage protection = protections[pid];
        require(
            protection.holder == msg.sender
            || operators[protection.holder][msg.sender] == true,
            "ProtectionPool::claim: !operator"
        );

        // ensure: settling, active, and !expiry
        require(conceptStatuses[protection.conceptIndex] == ConceptStatus.Settling,              "ProtectionPool::claim: !Settling");
        require(                       protection.status == Status.Active,                       "ProtectionPool::claim: !active");
        require(                       protection.start  <  claimTimes[protection.conceptIndex], "ProtectionPool::claim: !start");
        require(                      protection.expiry  >= claimTimes[protection.conceptIndex], "ProtectionPool::claim: expired");

        protection.status = Status.Claimed;

        // decrease utilized and reserves
        utilized = utilized.sub(protection.coverageAmount);
        reserves = reserves.sub(protection.coverageAmount);

        // transfer coverage + payment back to coverage holder
        uint256 payout = protection.coverageAmount.add(protection.paid);
        IERC20(payToken).safeTransfer(protection.holder, payout);
        emit Claim(protection.holder, pid, payout);
    }

    /// @notice Nonstandard transfer method because erc721 is a dumb standard
    function transfer(address who, uint256 pid)
        public
    {
        Protection storage protection = protections[pid];
        require(protection.holder == msg.sender,      "ProtectionPool::transfer: !protection owner");
        require(protection.expiry >= block.timestamp, "ProtectionPool::transfer: expired");
        require(protection.status == Status.Active,   "ProtectionPool::transfer: !active");
        require(              who != address(0),      "ProtectionPool::transfer: cannot burn protection");
        protection.holder = who;
        emit Transfer(msg.sender, who, pid);
    }

    // ERC721 kind of compliance. A lot of the standard is stupid so we dont implement all of it
    function setApprovalForAll(
        address operator,
        bool approved
    )
        public
    {
      operators[msg.sender][operator] = approved;
      emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(address from, address to, uint256 pid, bytes memory data)
        public
    {
        _safeTransferFrom(from, to, pid, data);
    }

    function safeTransferFrom(address from, address to, uint256 pid)
        public
    {
        _safeTransferFrom(from, to, pid, "");
    }

    function _safeTransferFrom(address from, address to, uint256 pid, bytes memory data)
        internal
    {
        require(
            from == msg.sender
            || operators[from][msg.sender] == true,
            "ProtectionPool::safeTransferFrom: !operator"
        );

        Protection storage protection = protections[pid];
        require(protection.holder == from,            "ProtectionPool::safeTransferFrom: from != holder");
        require(protection.expiry >= block.timestamp, "ProtectionPool::safeTransferFrom: expired");
        require(protection.status == Status.Active,   "ProtectionPool::safeTransferFrom: !active");
        require(               to != address(0),      "ProtectionPool::safeTransferFrom: cannot burn protection");

        protection.holder = to;
        emit Transfer(from, to, pid);

        // erc721 callback. dont check if contract, just if they provided data
        if (data.length > 0) {
            ERC721TokenReceiver(to).onERC721Received(msg.sender, from, pid, data);
            // no check for return because thats dumb. this callback is in case
            // an app expects it. if the contract doesnt, tough cookies, glhf
        }
    }

    // ============ Provider Functions ===========

    function provideCoverage(
        uint128 amount
    )
        public
        hasArbiter
        updateTokenSecondsProvided(msg.sender)
    {
        require(amount > 0, "ProtectionPool::provideCoverage: amount 0");
        providers[msg.sender].curTokens = providers[msg.sender].curTokens.add(amount);
        providers[msg.sender].lastProvide = safe32(block.timestamp);
        reserves = reserves.add(amount);

        // TODO delete before mainnet
        /* require(reserves <= MAX_RESERVES, "ProtectionPool::provideCoverage: Max reserves met for alpha"); */

        IERC20(payToken).safeTransferFrom(msg.sender, address(this), amount);
        emit ProvideCoverage(msg.sender, amount);
    }

    function balanceOf(address who)
        public
        view
        returns (uint256)
    {
        return providers[who].curTokens;
    }


    ///@notice initiates a withdraw request
    function intiateWithdraw()
        public
    {
        // update withdraw time iff end of grace period or have a superseding lock that ends after grace period
        if (
          block.timestamp > providers[msg.sender].withdrawInitiated + WITHDRAW_GRACE_PERIOD
          || providers[msg.sender].lastProvide + LOCKUP_PERIOD > providers[msg.sender].withdrawInitiated + WITHDRAW_GRACE_PERIOD
        ) {
            providers[msg.sender].withdrawInitiated = safe32(block.timestamp);
        }
    }

    function withdraw(uint128 amount)
        public
        updateTokenSecondsProvided(msg.sender)
    {
        require(        providers[msg.sender].withdrawInitiated + LOCKUP_PERIOD <  block.timestamp, "ProtectionPool::withdraw: locked");
        require(              providers[msg.sender].lastProvide + LOCKUP_PERIOD <  block.timestamp, "ProtectionPool::withdraw: locked2");
        require(providers[msg.sender].withdrawInitiated + WITHDRAW_GRACE_PERIOD >= block.timestamp, "ProtectionPool::withdraw: expired");


        // get premiums
        _claimPremiums();

        // update reserves & balance
        reserves = reserves.sub(amount);
        require(reserves >= utilized, "ProtectionPool::withdraw: !liquidity");
        providers[msg.sender].curTokens = providers[msg.sender].curTokens.sub(amount);

        // payout
        IERC20(payToken).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    /// @notice Claim premiums
    function claimPremiums()
        public
        updateTokenSecondsProvided(msg.sender)
    {
        _claimPremiums();
    }

    function _claimPremiums()
        internal
    {
        uint256 ttsp = providers[msg.sender].totalTokenSecondsProvided;
        if (ttsp > 0) {
            uint256 claimed = providers[msg.sender].claimed;

            uint256 claimable = _claimablePremiums(claimed, ttsp, totalProtectionSeconds);

            if (claimable == 0) {
                return;
            }

            providers[msg.sender].claimed = claimed.add(claimable);
            // payout
            IERC20(payToken).safeTransfer(msg.sender, claimable);
            emit ClaimPremiums(msg.sender, claimable);
        }
    }

    /// @notice Calculate claimable premiums for a provider
    function claimablePremiums(address who)
        public
        view
        returns (uint256)
    {
        uint256 timestamp = block.timestamp;
        uint256 newTokenSecondsProvided = (timestamp - providers[who].lastUpdate).mul(providers[who].curTokens);
        uint256 whoTPS = providers[who].totalTokenSecondsProvided.add(newTokenSecondsProvided);
        uint256 newTTPS = (timestamp - lastUpdatedTPS).mul(reserves);
        uint256 globalTPS = totalProtectionSeconds.add(newTTPS);
        return _claimablePremiums(providers[who].claimed, whoTPS, globalTPS);
    }

    function _claimablePremiums(uint256 claimed, uint256 providerTPS, uint256 globalTPS)
        internal
        view
        returns (uint256)
    {
        return premiumsAccum
                  .mul(providerTPS)
                  .div(globalTPS)
                  .sub(claimed);
    }

    /// @notice Sweep multiple sets of premiums into reserves
    function sweepPremiums(uint256[] memory pids)
        public
    {
        uint pidsLength = pids.length;
        uint128 totalSweptCoverage;
        uint128 totalPaid;
        for (uint256 i = 0; i < pidsLength; i++) {
            (uint128 coverageAmount, uint128 paid) = _sweep(pids[i]);
            totalSweptCoverage = totalSweptCoverage.add(coverageAmount);
            totalPaid          = totalPaid.add(paid);
        }
        _update(totalSweptCoverage, totalPaid);
    }

    /// @notice Sweep premium of a protection into reserves
    function sweep(uint256 pid)
        public
    {
        (uint128 coverageAmount, uint128 paid) = _sweep(pid);
        _update(coverageAmount, paid);
    }

    /// @dev sweeps a protection plan over to swept status
    function _sweep(uint256 pid)
        internal
        returns (uint128, uint128)
    {
        Protection storage protection = protections[pid];
        // ensure its expired, the concept isnt settling, and protection is active
        require(conceptStatuses[protection.conceptIndex] != ConceptStatus.Settling, "ProtectionPool::Sweep: Concept Settling");
        require(                  protection.status == Status.Active,          "ProtectionPool::Sweep: !active");
        require(                  protection.expiry <  block.timestamp,        "ProtectionPool::Sweep: !expired");

        // set status to swept
        protection.status = Status.Swept;
        emit Swept(pid, protection.paid);
        return (protection.coverageAmount, protection.paid);
    }

    /// @dev updates various vars relating to premiums and fees
    function _update(uint128 coverageRemoved, uint128 premiumsPaid)
        internal
    {
        utilized = utilized.sub(coverageRemoved);
        uint128 arbFees;
        uint128 createFees;
        uint128 rollovers;
        if (arbiterFee > 0) {
            arbFees = premiumsPaid.mul(arbiterFee).div(BASE);
            arbiterFees = arbiterFees.add(arbFees); // pay arbiter
        }
        if (creatorFee > 0) {
            createFees = premiumsPaid.mul(creatorFee).div(BASE);
            creatorFees = creatorFees.add(createFees); // pay creator
        }
        if (rollover > 0) {
            rollovers = premiumsPaid.mul(rollover).div(BASE);
            reserves = reserves.add(rollovers); // rollover some % of premiums into reserves
        }

        // push remaining premiums to premium pool
        // SAFETY: BASE is 10**18, all others are bounded such that sum(r, c, a) < BASE.
        premiumsAccum = premiumsAccum.add(premiumsPaid - arbFees - createFees - rollovers);
    }

    /// @notice Changes a settled market into a cooldown market
    function enterCooldown(uint8 conceptIndex)
        public
    {
        // make sure its current in settling mode and settlement mode is finished
        require(conceptStatuses[conceptIndex] == ConceptStatus.Settling,        "ProtectionPool::enterCooldown: !Settling");
        require(uint128(settleStart[conceptIndex]).add(SETTLE_LENGTH) < block.timestamp, "ProtectionPool::enterCooldown: Settling not finished");

        // change concept status to cooldown, intialize cooldown timer
        claimTimes[conceptIndex] = 0;
        conceptStatuses[conceptIndex] = ConceptStatus.Cooldown;
        cooldownStart[conceptIndex] = safe32(block.timestamp);
    }

    /// @notice Changes a cooldowned market into a active market
    function reactivateConcept(uint8 conceptIndex)
        public
    {
        // make sure its current in cooldown mode and cooldown mode is finished
        require(conceptStatuses[conceptIndex] == ConceptStatus.Cooldown, "ProtectionPool::enterCooldown: !Cooldown");
        require(uint128(cooldownStart[conceptIndex]).add(COOLDOWN_LENGTH) < block.timestamp, "ProtectionPool::enterCooldown: Cooldown not finished");

        // change concept status
        conceptStatuses[conceptIndex] = ConceptStatus.Active;
    }

    // ============ Arbiter Functions ============

    ///@notice Sets a concept as settling (allowing claims)
    function _setSettling(uint8 conceptIndex, uint32 settleTime)
        public
        onlyArbiter
    {
        // change status to settling
        conceptStatuses[conceptIndex] = ConceptStatus.Settling;

        // start settle timer
        settleStart[conceptIndex] = safe32(block.timestamp);

        // set claim time
        claimTimes[conceptIndex] = settleTime;

    }

    ///@notice Arbiter accept arbiter role
    function _acceptArbiter()
        public
        onlyArbiter
    {
        require(!accepted, "ProtectionPool::_acceptArbiter: Arbiter has already accepted/abdicated.");
        arbSet = true;
        accepted = true;
    }

    ///@notice Arbiter get fees
    function _getArbiterFees()
        public
        onlyArbiter
    {
        uint128 a_fees = arbiterFees;
        arbiterFees = 0;
        IERC20(payToken).safeTransfer(arbiter, a_fees);
        emit ArbiterPaid(a_fees);
    }

    ///@notice Abdicates arbiter role, effectively shutting down the pool
    function _abdicate()
        public
        onlyArbiter
    {
        arbSet = false;
    }

    // ============ Creator Functions ============
    function _getCreatorFees()
        public
    {
        require(msg.sender == creator, "!creator");
        uint128 c_fees = creatorFees;
        creatorFees = 0;
        IERC20(payToken).safeTransfer(creator, c_fees);
        emit CreatorPaid(c_fees);
    }

    // ============ Helper Functions ============
    function safe32(uint256 n)
        internal
        pure
        returns (uint32)
    {
        require(n < 2**32, "Bad safe32 cast");
        return uint32(n);
    }
}
