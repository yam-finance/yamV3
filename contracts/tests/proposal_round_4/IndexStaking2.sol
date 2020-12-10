pragma solidity 0.5.15;

import "../index_staking/ReserveUniHelper.sol";

interface IndexStaker {
    function stake(uint256) external;
    function withdraw(uint256) external;
    function getReward() external;
    function exit() external;
    function balanceOf(address) external view returns (uint256);
    function earned(address account) external view returns (uint256);
}

contract IndexStaking2 is ReserveUniHelper {

    constructor(address pendingGov_, address reserves_) public {
        gov = msg.sender;
        pendingGov = pendingGov_;
        reserves = reserves_;
        IERC20(lp).approve(address(staking), uint256(-1));
    }

    IndexStaker public staking = IndexStaker(0xB93b505Ed567982E2b6756177ddD23ab5745f309);

    address public lp = address(0x4d5ef58aAc27d99935E5b6B4A6778ff292059991);

    function currentStake()
        public
        view
        returns (uint256)
    {
        return staking.balanceOf(address(this));
    }

    // callable by anyone assuming twap bounds checks
    function stake()
        public
    {
        _getLPToken();
        uint256 amount = IERC20(lp).balanceOf(address(this));
        staking.stake(amount);
    }

    // callable by anyone assuming twap bounds checks
    function getUnderlying()
        public
    {
        _getUnderlyingToken(true);
    }

    // ========= STAKING ========
    function _stakeCurrentLPBalance()
        public
        onlyGovOrSubGov
    {
        uint256 amount = IERC20(lp).balanceOf(address(this));
        staking.stake(amount);
    }

    function _approveStakingFromReserves(
        bool isToken0Limited,
        uint256 amount
    )
        public
        onlyGovOrSubGov
    {
        if (isToken0Limited) {
          setup_twap_bound(
              UniswapPair(lp).token0(), // The limiting asset
              UniswapPair(lp).token1(),
              amount, // amount of token0
              true, // is sale
              60 * 60, // 1 hour
              5 * 10**15, // .5%
              lp,
              address(0), // if two hop
              60 * 60 // length after twap update that it can occur
          );
        } else {
          setup_twap_bound(
              UniswapPair(lp).token1(), // The limiting asset
              UniswapPair(lp).token0(),
              amount, // amount of token1
              true, // is sale
              60 * 60, // 1 hour
              5 * 10**15, // .5%
              lp,
              address(0), // if two hop
              60 * 60 // length after twap update that it can occur
          );
        }
    }
    // ============================

    // ========= EXITING ==========
    function _exitStaking()
        public
        onlyGovOrSubGov
    {
        staking.exit();
    }

    function _exitAndApproveGetUnderlying()
        public
        onlyGovOrSubGov
    {
        staking.exit();
        setup_twap_bound(
            UniswapPair(lp).token0(), // doesnt really matter
            UniswapPair(lp).token1(), // doesnt really matter
            staking.balanceOf(address(this)), // amount of LP tokens
            true, // is sale
            60 * 60, // 1 hour
            5 * 10**15, // .5%
            lp,
            address(0), // if two hop
            60 * 60 // length after twap update that it can occur
        );
    }

    function _exitStakingEmergency()
        public
        onlyGovOrSubGov
    {
        staking.withdraw(staking.balanceOf(address(this)));
    }

    function _exitStakingEmergencyAndApproveGetUnderlying()
        public
        onlyGovOrSubGov
    {
        staking.withdraw(staking.balanceOf(address(this)));
        setup_twap_bound(
            UniswapPair(lp).token0(), // doesnt really matter
            UniswapPair(lp).token1(), // doesnt really matter
            staking.balanceOf(address(this)), // amount of LP tokens
            true, // is sale
            60 * 60, // 1 hour
            5 * 10**15, // .5%
            lp,
            address(0), // if two hop
            60 * 60 // length after twap update that it can occur
        );
    }
    // ============================


    function _getTokenFromHere(address token)
        public
        onlyGovOrSubGov
    {
        IERC20 t = IERC20(token);
        t.transfer(reserves, t.balanceOf(address(this)));
    }
}
