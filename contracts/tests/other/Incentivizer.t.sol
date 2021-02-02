// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;

import "../../lib/SafeMath.sol";
import {DSTest} from "../../lib/test.sol";
import {YAMDelegator} from "../../token/YAMDelegator.sol";
import {YAMDelegate3} from "../../token/YAMDelegate3.sol";
import {YamIncentivizerWithVoting} from "../../incentivizers/YamIncentivizerWithVoting.sol";
import "../../lib/UniswapRouterInterface.sol";
import "../../lib/SafeERC20.sol";

interface Hevm {
    function warp(uint) external;
    function store(address,bytes32,bytes32) external;
}

interface YAMv2 {
    function decimals() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function approve(address,uint) external returns (bool);
}

interface YYCRV {
  function deposit(uint256 _amount) external;
  function withdraw(uint256 shares) external;
}

contract User {

}

contract YAMMigratorTest is DSTest {
    using SafeMath for uint256;

    UniRouter2 uniRouter = UniRouter2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    Hevm hevm;
    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint(keccak256('hevm cheat code'))));

    YAMDelegate3 delegate;

    YAMDelegator yamV3;

    YamIncentivizerWithVoting incentives;

    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    address multiSig = address(0x0114ee2238327A1D12c2CeB42921EFe314CBa6E6);

    address gitcoinGrants = address(0xde21F729137C5Af1b01d73aF1dC21eFfa2B8a0d6);

    address uniFact = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    address yyCRV = address(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);

    address WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address yCRV = address(0xdF5e0e81Dff6FAF3A7e52BA697820c5e32D806A8);

    YAMv2 yamV2;

    User user;

    address me;

    function setupIncentivizer() public {
        incentives = new YamIncentivizerWithVoting();
        incentives.setRewardDistribution(me);
        yamV3._setIncentivizer(address(incentives));
        incentives.notifyRewardAmount(0);
        /* assertEq(yamV3.balanceOf(address(incentives)), 925 * 10**2 * 10**18); */
    }

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));
        me  = address(this);

        // Cuurrent YAM v2 token
        yamV2 = YAMv2(0xAba8cAc6866B83Ae4eec97DD07ED254282f6aD8A);

        // Create an implementation
        delegate = new YAMDelegate3();

        // Create delegator
        yamV3 = new YAMDelegator(
            "YAMv3",
            "YAMv3",
            18,
            210000*10**18,
            address(delegate),
            ""
        );

        setupIncentivizer();

        // User for testing
        user = new User();
    }

    //
    // TESTS
    //

    function test_breaker() public {
        createPoolAndStartIncentives();
        incentives.setBreaker(true);
        hevm.warp(incentives.starttime() + incentives.DURATION());
        uint256 earned = incentives.earned(me);
        hevm.warp(now + 86400*100);
        uint256 earned2 = incentives.earned(me);
        assertEq(earned, earned2);
        incentives.exit();
    }


    function test_breaker_after_week1() public {
        createPoolAndStartIncentives();

        hevm.warp(incentives.starttime() + incentives.DURATION());
        incentives.getReward();
        incentives.setBreaker(true);
        hevm.warp(incentives.starttime() + incentives.DURATION()*2);
        uint256 earned = incentives.earned(me);
        hevm.warp(now + 86400*100);
        uint256 earned2 = incentives.earned(me);
        assertEq(earned, earned2);
        incentives.exit();
    }

    function createPoolAndStartIncentives() public {
        createYYCRV_YAMPool();

        IERC20 yyCRVPool = IERC20(pairFor(uniFact, address(yamV3), yyCRV));

        yyCRVPool.approve(address(incentives), uint256(-1));
        // wait until incentive pool launch
        hevm.warp(incentives.starttime());

        uint256 lp_bal = yyCRVPool.balanceOf(me);

        // lets do some staking
        incentives.stake(lp_bal);

        assertEq(incentives.balanceOf(me), lp_bal);
    }

    function createYYCRV_YAMPool() internal {
        getYYCRV();
        IERC20(yyCRV).approve(address(uniRouter), uint256(-1));
        yamV3.approve(address(uniRouter), uint256(-1));
        uniRouter.addLiquidity(
            address(yamV3),
            yyCRV,
            IERC20(yyCRV).balanceOf(me) / 2, // equal amounts
            IERC20(yyCRV).balanceOf(me) / 2,
            1,
            1,
            me,
            now + 60
        );
    }

    function getYYCRV() internal {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = yCRV;
        uniRouter.swapExactETHForTokens.value(10**18)(1, path, me, now + 60);
        uint256 balance = IERC20(yCRV).balanceOf(me);
        uint256 allowance = IERC20(yCRV).allowance(me, yyCRV);
        if (allowance == 0) {
          IERC20(yCRV).approve(yyCRV, uint256(-1));
        }
        YYCRV(yyCRV).deposit(balance);
    }

    function pairFor(
        address factory,
        address token0,
        address token1
    )
        internal
        pure
        returns (address pair)
    {
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }
}
