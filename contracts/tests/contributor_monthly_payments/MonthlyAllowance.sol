pragma solidity 0.5.15;

import "../../lib/IERC20.sol";
import "../../lib/SafeERC20.sol";
import "../../lib/SafeMath.sol";

contract MonthlyAllowance {
    using SafeMath for uint256;


    /// @notice Monthly transfer limit - hardcoded to 100,000
    uint256 public constant MONTHLY_LIMIT = 100000 ether;

    /// @notice One month worth of seconds
    uint256 public constant ONE_MONTH = 30 days;

    /// @notice Asset used for payments
    IERC20 public paymentAsset;

    /// @notice Reserves contract to spend from
    address public reserves;

    /// @notice Amount spent per epoch
    mapping(uint256 => uint256) public spentPerEpoch;

    /// @notice Has been initialized
    bool public initialized;

    /// @notice Time initialization happened at - if not initialized, it's 0
    uint256 public timeInitialized;

    /// @notice One way breaker for closing payments from this contract
    bool public breaker;

    /// @notice sub governors
    mapping(address => bool) public isSubGov;

    /// @notice governor
    address public gov;

    /// @notice pending governor
    address public pendingGov;

    /**
     * @notice Event emitted when pendingGov is changed
     */
    event NewPendingGov(
        address oldPendingGov, 
        address newPendingGov
    );

    /**
     * @notice Event emitted when gov is changed
     */
    event NewGov(
        address oldGov, 
        address newGov
    );

    /**
     * @notice Event emitted when a sub gov is enabled/disabled
     */
    event SubGovModified(
        address account, 
        bool isSubGov
    );

    /**
     * @notice Event emitted when a payment is successfully made 
     */
    event Payment(
        address indexed recipient,
        uint256 assetAmount
    );

    modifier onlyGov() {
        require(msg.sender == gov, "MonthlyAllowance::onlyGov: account is not gov");
        _;
    }

    modifier onlyGovOrSubGov() {
        require(msg.sender == gov || isSubGov[msg.sender]);
        _;
    }

    modifier breakerNotSet() {
        require(!breaker, "MonthlyAllowance::breakerNotSet: breaker is set");
        _;
    }
    
    constructor(address _paymentAsset, address _reserves) public {
      gov = msg.sender;
      paymentAsset = IERC20(_paymentAsset);
      reserves = _reserves;
    }

    function initialize()
        public
        onlyGov
    {
        require(!initialized, "MonthlyAllowance::initialize: Contract is already initialized");
        timeInitialized = block.timestamp;
        initialized = true;
    }

    function pay(address recipient, uint256 amount)
        public
        onlyGovOrSubGov
        breakerNotSet
    {
        require(initialized, "MonthlyAllowance::pay: Contract not initialized");
        uint256 epoch = _currentEpoch();
        uint256 newPaidThisEpoch = spentPerEpoch[epoch].add(amount);
        require(newPaidThisEpoch <= MONTHLY_LIMIT, "MonthlyAllowance::pay: Monthly allowance exceeded");
        spentPerEpoch[epoch] = newPaidThisEpoch;
        SafeERC20.safeTransferFrom(paymentAsset, reserves, recipient, amount);
    }

    function currentEpoch()
        public
        returns (uint256)
    {
        return _currentEpoch();
    }

    function _currentEpoch()
        internal
        returns (uint256)
    {
        uint256 timeSinceInitialization = block.timestamp - timeInitialized;
        uint256 epoch = timeSinceInitialization / ONE_MONTH;
        return epoch;
    }

    function flipBreaker()
        public
        onlyGov
        breakerNotSet
    {
        breaker = true;
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

    function setIsSubGov(address subGov, bool _isSubGov)
        public
        onlyGov
    {
        isSubGov[subGov] = _isSubGov;
        emit SubGovModified(subGov, _isSubGov);
    }


}
