pragma solidity 0.5.15;

import "../../lib/SafeERC20.sol";
import {YAMDelegate2} from "../proposal_round_2/YAMDelegate.sol";

contract VestingPool {
    using SafeMath for uint256;
    using SafeMath for uint128;

    struct Stream {
        address recipient;
        uint128 startTime;
        uint128 length;
        uint256 totalAmount;
        uint256 amountPaidOut;
    }
    
    /**
     * @notice Governor for this contract
     */
    address public gov;

    /**
     * @notice Pending governance for this contract
     */
    address public pendingGov;

    /// @notice Mapping containing valid stream managers
    mapping(address => bool) public isStreamManager;

    /// @notice Amount of tokens allocated to streams that hasn't yet been claimed
    uint256 public totalUnclaimedInStreams;

    /// @notice The number of streams created so far
    uint256 public streamCount;

    /// @notice All streams
    mapping(uint256 => Stream) public streams;

    /// @notice YAM token
    YAMDelegate2 public yam;

    /**
     * @notice Event emitted when a stream manager is enabled/disabled
     */
    event StreamManagerModified(
        address account,
        bool isMod
    );

    /**
     * @notice Event emitted when stream is opened
     */
    event StreamOpened(
        address indexed account,
        uint256 indexed streamId,
        uint256 length,
        uint256 totalAmount
    );

    /**
     * @notice Event emitted when stream is closed
     */
    event StreamClosed(
        uint256 indexed streamId
    );

    /**
     * @notice Event emitted on payout
     */
    event Payout(
        uint256 indexed streamId,
        address indexed recipient,
        uint256 amount
    );

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

    constructor(YAMDelegate2 _yam) public {
        gov = msg.sender;
        yam = _yam;
    }

    modifier onlyGov() {
        require(msg.sender == gov, "VestingPool::onlyGov: account is not owner");
        _;
    }

    modifier canManageStreams() {
        require(
            isStreamManager[msg.sender] || (msg.sender == gov),
            "VestingPool::canManageStreams: account cannot manage streams"
        );
        _;
    }

    /**
     * @dev Opens a new stream that continuously pays out.
     * @param recipient Account that will receive the funds.
     * @param length The amount of time in seconds that the stream lasts
     * @param totalAmount The total amount to payout in the stream
     */
    function openStream(
        address recipient,
        uint128 length,
        uint256 totalAmount
    ) 
        public
        canManageStreams
        returns (uint256 streamIndex)
    {
        require(
            totalUnclaimedInStreams.add(totalAmount) <=
                yam.balanceOfUnderlying(address(this))
        );
        require(length > 0);
        streamIndex = streamCount++;
        streams[streamIndex] = Stream({
            recipient: recipient,
            length: length,
            startTime: uint128(block.timestamp),
            totalAmount: totalAmount,
            amountPaidOut: 0
        });
        totalUnclaimedInStreams = totalUnclaimedInStreams.add(totalAmount);
        emit StreamOpened(recipient, streamIndex, length, totalAmount);
    }

    /**
     * @dev Closes the specified stream. Pays out pending amounts, clears out the stream, and emits a StreamClosed event.
     * @param streamId The id of the stream to close.
     */
    function closeStream(uint256 streamId)
        public
        canManageStreams
    {
        payout(streamId);
        streams[streamId] = Stream(
            address(0x0000000000000000000000000000000000000000),
            0,
            0,
            0,
            0
        );
        emit StreamClosed(streamId);
    }

   /**
     * @dev Pays out pending amount in a st ream
     * @param streamId The id of the stream to payout.
     * @return The amount paid out in underlying
     */
    function payout(uint256 streamId)
        public
        returns (uint256 paidOut)
    {
        uint128 currentTime = uint128(block.timestamp);
        Stream memory stream = streams[streamId];
        require(
            stream.startTime <= currentTime,
            "VestingPool::payout: Stream hasn't started yet"
        );
        uint256 claimableUnderlying = _claimable(stream);

        streams[streamId].amountPaidOut = stream.amountPaidOut.add(
            claimableUnderlying
        );

        totalUnclaimedInStreams = totalUnclaimedInStreams.sub(
            claimableUnderlying
        );

        yam.transferUnderlying(stream.recipient, claimableUnderlying);

        emit Payout(streamId, stream.recipient, claimableUnderlying);
    }

   /**
     * @dev The amount that is claimable for a stream
     * @param streamId The stream to get the claimabout amount for.
     * @return The amount that is claimable for this stream
     */
    function claimable(uint256 streamId)
        external
        view
        returns (uint256 claimableUnderlying)
    {
        Stream memory stream = streams[streamId];
        return _claimable(stream);
    }

    function _claimable(Stream memory stream)
        internal
        view
        returns (uint256 claimableUnderlying)
    {
        uint128 currentTime = uint128(block.timestamp);
        uint128 elapsedTime = currentTime - stream.startTime;
        if (currentTime >= stream.startTime + stream.length) {
            claimableUnderlying = stream.totalAmount - stream.amountPaidOut;
        } else {
            claimableUnderlying = elapsedTime
                .mul(stream.totalAmount)
                .div(stream.length)
                .sub(stream.amountPaidOut);
        }
    }

   /** 
     * @dev Set whether an account can open/close streams. Only callable by the current gov contract
     * @param account The acount to set permissions for.
     * @param _isStreamManager Whether or not this account can manage streams
     */
    function setIsStreamManager(address account, bool _isStreamManager)
        public
        onlyGov
    {
        isStreamManager[account] = _isStreamManager;
        emit StreamManagerModified(account, _isStreamManager);
    }

    /** @notice sets the pendingGov
     * @param pendingGov_ The address of the contract to use for authentication.
     */
    function _setPendingGov(address pendingGov_)
        external
        onlyGov
    {
        address oldPendingGov = pendingGov;
        pendingGov = pendingGov_;
        emit NewPendingGov(oldPendingGov, pendingGov_);
    }

    /** @notice accepts governance over this contract
     *
     */
    function _acceptGov()
        external
    {
        require(msg.sender == pendingGov, "!pending");
        address oldGov = gov;
        gov = pendingGov;
        pendingGov = address(0);
        emit NewGov(oldGov, gov);
    }

}
