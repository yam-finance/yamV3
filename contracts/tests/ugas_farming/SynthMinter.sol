pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

interface SynthMinter {
    struct Unsigned {
        uint256 rawValue;
    }
    struct PositionData {
        Unsigned tokensOutstanding;
        // Tracks pending withdrawal requests. A withdrawal request is pending if `withdrawalRequestPassTimestamp != 0`.
        uint256 withdrawalRequestPassTimestamp;
        Unsigned withdrawalRequestAmount;
        // Raw collateral value. This value should never be accessed directly -- always use _getFeeAdjustedCollateral().
        // To add or remove collateral, use _addCollateral() and _removeCollateral().
        Unsigned rawCollateral;
        // Tracks pending transfer position requests. A transfer position request is pending if `transferPositionRequestPassTimestamp != 0`.
        uint256 transferPositionRequestPassTimestamp;
    }

    function create(
        Unsigned calldata collateralAmount,
        Unsigned calldata numTokens
    ) external;


    function redeem(Unsigned calldata debt_amount) external returns(Unsigned memory);

    function withdraw(Unsigned calldata collateral_amount) external;

    function positions(address account) external returns (PositionData memory);

    function settleExpired() external returns (Unsigned memory);

    function expire() external;
}