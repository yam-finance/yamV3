pragma solidity 0.5.15;

import "../../lib/SafeERC20.sol";
import "../../token/YAM.sol";

contract VestingPool {
    using SafeMath for uint256;
    using SafeMath for uint128;

    /// @notice Mapping containins valid admins
    address public owner;

    /// @notice Mapping containing valid mods
    mapping(address => bool) public isStreamManager;

    /// @notice Amount of tokens allocated to streams that hasn't yet been claimed
    uint256 public totalUnclaimedInStreams;

    /// @notice The number of streams created so far
    uint256 public streamCount;

    /// @notice All streams
    mapping(uint256 => Stream) public streams;

    /// @notice The token that streams are created for
    YAM public yam;

    event StreamManagerModified(address account, bool isMod);
    event OwnerModified(
        address indexed previousOwner,
        address indexed newOwner
    );

    event StreamOpened(
        address indexed account,
        uint256 indexed streamId,
        uint256 length,
        uint256 totalAmount
    );

    constructor(address _owner, YAM _yam) public {
        owner = _owner;
        yam = _yam;
    }

    modifier isOwner() {
        require(
            msg.sender == owner,
            "VestingPool::_isOwner: account is not owner"
        );
        _;
    }

    modifier canManageStreams() {
        require(
            isStreamManager[msg.sender] || (msg.sender == owner),
            "VestingPool::_canManageStreams: account cannot manage streams"
        );
        _;
    }

    function openStream(
        address recipient,
        uint128 length,
        uint256 totalAmount
    ) public canManageStreams returns (uint256 streamIndex) {
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

    function closeStream(uint256 streamId) public canManageStreams {
        payout(streamId);
        streams[streamId] = Stream(
            address(0x0000000000000000000000000000000000000000),
            0,
            0,
            0,
            0
        );
    }

    function payout(uint256 streamId) public {
        uint128 currentTime = uint128(block.timestamp);
        Stream memory stream = streams[streamId];
        require(
            stream.startTime <= currentTime,
            "VestingPool::payout: Stream hasn't started yet"
        );
        uint256 claimableUnderlying;
        uint256 claimableBalance;
        (claimableUnderlying, claimableBalance) = _claimable(stream);

        SafeERC20.safeTransfer(
            IERC20(address(yam)),
            stream.recipient,
            claimableBalance
        );

        streams[streamId].amountPaidOut = stream.amountPaidOut.add(
            claimableUnderlying
        );
        totalUnclaimedInStreams = totalUnclaimedInStreams.sub(
            claimableUnderlying
        );
    }

    function claimable(uint256 streamId)
        external
        view
        returns (uint256 claimableUnderlying, uint256 claimableBalance)
    {
        Stream memory stream = streams[streamId];
        return _claimable(stream);
    }

    function _claimable(Stream memory stream)
        internal
        view
        returns (uint256 claimableUnderlying, uint256 claimableBalance)
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
        claimableBalance = yam.yamToFragment(claimableUnderlying);
        claimableUnderlying = yam.fragmentToYam(claimableBalance);
    }

    function setIsStreamManager(address account, bool _isStreamManager)
        public
        isOwner
    {
        isStreamManager[account] = _isStreamManager;
        emit StreamManagerModified(account, _isStreamManager);
    }

    function setOwner(address account) public isOwner {
        owner = account;
        emit OwnerModified(msg.sender, account);
    }

    struct Stream {
        address recipient;
        uint128 startTime;
        uint128 length;
        uint256 totalAmount;
        uint256 amountPaidOut;
    }
}
