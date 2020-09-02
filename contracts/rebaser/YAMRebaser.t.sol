// SPDX-License-Identifier: MIT

pragma solidity 0.5.15;

import "../lib/SafeMath.sol";
import "../lib/SafeERC20.sol";
import {DSTest} from "../lib/test.sol";
import {YAMDelegator} from "../token/YAMDelegator.sol";
import {YAMDelegate} from "../token/YAMDelegate.sol";
import {Migrator} from "../migrator/Migrator.sol";
import "./YAMRebaser.sol";
import "../lib/UniswapRouterInterface.sol";

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
  function do_addSyncPairs(YAMRebaser rebaser, address[] calldata uniSyncPairs_, address[] calldata balGulpPairs_) external {
      rebaser.addSyncPairs(uniSyncPairs_, balGulpPairs_);
  }

  function do_setMaxSlippageFactor(YAMRebaser rebaser, uint256 maxSlippageFactor_) external {
      rebaser.setMaxSlippageFactor(maxSlippageFactor_);
  }

  function do_setRebaseMintPerc(YAMRebaser rebaser, uint256 rebaseMintPerc_) external {
      rebaser.setRebaseMintPerc(rebaseMintPerc_);
  }

  function do_setReserveContract(YAMRebaser rebaser, address reservesContract_) external {
      rebaser.setReserveContract(reservesContract_);
  }

  function do__setPendingGov(YAMRebaser rebaser, address pendingGov_) external {
      rebaser._setPendingGov(pendingGov_);
  }

  function do__acceptGov(YAMRebaser rebaser) external {
      rebaser._acceptGov();
  }

  function do_init_twap(YAMRebaser rebaser) external {
      rebaser.init_twap();
  }

  function do_activate_rebasing(YAMRebaser rebaser) external {
      rebaser.activate_rebasing();
  }

  function do_rebase(YAMRebaser rebaser) external {
      rebaser.rebase();
  }

  function do_approve(YAMDelegator yamV3, YAMRebaser rebaser) external {
      yamV3.approve(address(rebaser), uint256(-1));
  }
}

contract YAMRebaserTest is DSTest {
    using SafeMath for uint256;

    Hevm hevm;
    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint(keccak256('hevm cheat code'))));

    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    address uniFact = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    address yyCRV = address(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);

    address WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    UniRouter2 uniRouter = UniRouter2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    address yCRV = address(0xdF5e0e81Dff6FAF3A7e52BA697820c5e32D806A8);

    YAMv2 yamV2;

    YAMDelegate delegate;

    YAMDelegator yamV3;

    Migrator migration;

    YAMRebaser rebaser;

    address me;

    User user;

    uint256 public constant BASE = 10**18;

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        // Cuurrent YAM v2 token
        yamV2 = YAMv2(0xAba8cAc6866B83Ae4eec97DD07ED254282f6aD8A);

        // Create an implementation
        delegate = new YAMDelegate();

        // Create delegator, mint us some YAMv3
        yamV3 = new YAMDelegator(
            "YAMv3",
            "YAMv3",
            18,
            10000*10**18,
            address(delegate),
            ""
        );

        assert(yamV3.yamsScalingFactor() == BASE);

        me = address(this);

        // Create a new migration for testing
        migration = new Migrator();

        // User for testing
        user = new User();

        rebaser = new YAMRebaser(
            address(yamV3),
            yyCRV,
            uniFact,
            address(user),
            address(0x232C95A72F132392171831cEcEc8c1161975c398),
            10**16 // 1%
        );

        yamV3._setMigrator(address(migration));
        assert(yamV3.migrator() == address(migration));

        // set v3
        migration.setV3Address(address(yamV3));

        migration.delegatorRewardsDone();

        // Warp to start of migration
        hevm.warp(migration.startTime());

        yamV2.approve(address(migration), uint256(-1));

        // get v3 tokens
        migration.migrate();

        // set rebaser
        yamV3._setRebaser(address(rebaser));

        yamV3.mint(me, 100000 * 10**18);
        user.do_approve(yamV3, rebaser);
    }

    //
    // TESTS
    //
    function test_addSyncPairs() public {
        address dai_yam = pairFor(uniFact, address(yamV3), dai);
        address[] memory unis = new address[](1);
        address[] memory bals = new address[](0);
        unis[0] = dai_yam;
        rebaser.addSyncPairs(unis, bals);
        address[] memory pairs = rebaser.getUniSyncPairs();
        assertEq(pairs[1], dai_yam);
    }

    function test_setMaxSlippage() public {
        rebaser.setMaxSlippageFactor(10**17);
        assertEq(rebaser.maxSlippageFactor(), 10**17);
    }

    function testFail_setMaxSlippage() public {
        user.do_setMaxSlippageFactor(rebaser, 10**17);
    }

    function test_setRebaseMintPerc() public {
        rebaser.setRebaseMintPerc(10**17);
        assertEq(rebaser.rebaseMintPerc(), 10**17);
    }

    function testFail_setRebaseMintPerc() public {
        user.do_setRebaseMintPerc(rebaser, 10**17);
    }

    function test_setReserveContract() public {
        rebaser.setReserveContract(me);
        assertEq(rebaser.reservesContract(), me);
    }

    function testFail_setReserveContract() public {
        user.do_setReserveContract(rebaser, me);
    }

    function test_setPendingGov() public {
        rebaser._setPendingGov(me);
        assertEq(rebaser.pendingGov(), me);
    }

    function testFail_setPendingGov() public {
        user.do__setPendingGov(rebaser, me);
    }

    function test_setGov() public {
        rebaser._setPendingGov(address(user));
        assertEq(rebaser.pendingGov(), address(user));
        user.do__acceptGov(rebaser);
        assertEq(rebaser.gov(), address(user));
    }

    function testFail_setGov() public {
        user.do__setPendingGov(rebaser, me);
        user.do__acceptGov(rebaser);
    }

    function test_initTwap() public {
        init_twap();
        assertEq(rebaser.timeOfTWAPInit(), now);
    }

    function testFail_initTwap() public {
        rebaser.init_twap();
    }

    function testFail_initTwapAlreadyInited() public {
        init_twap();
        init_twap();
    }

    function test_activateRebasing() public {
        init_twap();
        hevm.warp(now + rebaser.rebaseDelay());
        rebaser.activate_rebasing();
        assertTrue(rebaser.rebasingActive());
    }

    function testFail_activateRebasing_not_twap() public {
        rebaser.activate_rebasing();
    }

    function testFail_activateRebasing_not_delay() public {
        init_twap();
        rebaser.activate_rebasing();
    }

    function test_positive_rebase() public {
        init_twap();
        hevm.warp(now + rebaser.rebaseDelay());
        rebaser.activate_rebasing();
        assertTrue(rebaser.rebasingActive());
        pos_rebase();
    }

    function test_negative_rebase() public {
        init_twap();
        hevm.warp(now + rebaser.rebaseDelay());
        rebaser.activate_rebasing();
        assertTrue(rebaser.rebasingActive());
        neg_rebase();
    }

    function test_double_negative_rebase() public {
        init_twap();
        hevm.warp(now + rebaser.rebaseDelay());
        rebaser.activate_rebasing();
        assertTrue(rebaser.rebasingActive());
        neg_rebase();
        neg_rebase();
    }

    function test_double_pos_rebase() public {
        init_twap();
        hevm.warp(now + rebaser.rebaseDelay());
        rebaser.activate_rebasing();
        assertTrue(rebaser.rebasingActive());
        pos_rebase();
        pos_rebase();
    }

    // long running
    function test_rebase_scenario() public {
        init_twap();
        hevm.warp(now + rebaser.rebaseDelay());
        rebaser.activate_rebasing();
        assertTrue(rebaser.rebasingActive());
        pos_rebase();
        pos_rebase();
        neg_rebase();
        neg_rebase();
        pos_rebase();
    }


    function neg_rebase() internal {
      hevm.warp(now + 6 hours);
      uint256 twap = rebaser.getCurrentTWAP();
      while (twap >= 95 * 10**16) {
        push_price_down();
        hevm.warp(now + 6 hours);
        twap = rebaser.getCurrentTWAP();
      }
      assertTrue(rebaser.getCurrentTWAP() < 95 * 10**16);


      hevm.warp(now + 12 hours);
      uint256 offset = rebaser.rebaseWindowOffsetSec();
      uint256 interval = rebaser.minRebaseTimeIntervalSec();
      uint256 waitTime;
      if (now % interval > offset) {
        waitTime = (interval - (now % interval)) + offset;
      } else {
        waitTime = offset - (now % interval);
      }
      hevm.warp(now + waitTime);
      uint256 epoch = rebaser.epoch();
      uint256 pre_scalingFactor = yamV3.yamsScalingFactor();

      address yyCRVPool = pairFor(uniFact, address(yamV3), yyCRV);
      uint256 pre_balance = yamV3.balanceOf(me)
                            + yamV3.balanceOf(yyCRVPool)
                            + yamV3.balanceOf(address(user));
      uint256 pre_underlying = yamV3.balanceOfUnderlying(me)
                            + yamV3.balanceOfUnderlying(yyCRVPool)
                            + yamV3.balanceOfUnderlying(address(user));

      rebaser.rebase();
      assertEq(rebaser.epoch(), epoch + 1);
      assertEq(rebaser.blockTimestampLast(), now);

      // negative rebase
      uint256 balance = yamV3.balanceOf(me)
                            + yamV3.balanceOf(yyCRVPool)
                            + yamV3.balanceOf(address(user));
      uint256 underlying = yamV3.balanceOfUnderlying(me)
                            + yamV3.balanceOfUnderlying(yyCRVPool)
                            + yamV3.balanceOfUnderlying(address(user));

      assertTrue(pre_balance > balance);
      assertEq(pre_underlying, underlying);

      uint256 scalingFactor = yamV3.yamsScalingFactor();
      assertTrue(scalingFactor < pre_scalingFactor);

      // there can be rounding errors here
      assertTrue(yamV3.totalSupply() - balance < 5);

      assertEq(yamV3.totalSupply(), yamV3.initSupply().mul(scalingFactor).div(10**24));

      assertEq(yamV3.initSupply(), underlying);
    }



    function pos_rebase() internal {
      hevm.warp(now + 6 hours);
      uint256 twap = rebaser.getCurrentTWAP();
      while (twap <= 105 * 10**16) {
        push_price_up();
        hevm.warp(now + 6 hours);
        twap = rebaser.getCurrentTWAP();
      }



      assertTrue(rebaser.getCurrentTWAP() > 105 * 10**16);

      hevm.warp(now + 12 hours);

      uint256 offset = rebaser.rebaseWindowOffsetSec();
      uint256 interval = rebaser.minRebaseTimeIntervalSec();
      uint256 waitTime;
      if (now % interval > offset) {
        waitTime = (interval - (now % interval)) + offset;
      } else {
        waitTime = offset - (now % interval);
      }
      hevm.warp(now + waitTime);
      uint256 epoch = rebaser.epoch();
      uint256 pre_scalingFactor = yamV3.yamsScalingFactor();

      address yyCRVPool = pairFor(uniFact, address(yamV3), yyCRV);
      uint256 pre_balance = yamV3.balanceOf(me)
                            + yamV3.balanceOf(yyCRVPool)
                            + yamV3.balanceOf(address(user));
      uint256 pre_underlying = yamV3.balanceOfUnderlying(me)
                            + yamV3.balanceOfUnderlying(yyCRVPool)
                            + yamV3.balanceOfUnderlying(address(user));

      assertTrue(rebaser.inRebaseWindow());
      rebaser.rebase();
      assertEq(rebaser.epoch(), epoch + 1);
      assertEq(rebaser.blockTimestampLast(), now);

      // positive rebase
      uint256 balance = yamV3.balanceOf(me)
                            + yamV3.balanceOf(yyCRVPool)
                            + yamV3.balanceOf(address(user));
      uint256 underlying = yamV3.balanceOfUnderlying(me)
                            + yamV3.balanceOfUnderlying(yyCRVPool)
                            + yamV3.balanceOfUnderlying(address(user));

      assertTrue(pre_balance < balance);
      assertTrue(pre_underlying < underlying);

      uint256 scalingFactor = yamV3.yamsScalingFactor();
      assertTrue(scalingFactor > pre_scalingFactor);

      // there can be rounding errors here
      assertTrue(yamV3.totalSupply() - balance < 5);

      assertEq(yamV3.totalSupply(), yamV3.initSupply().mul(scalingFactor).div(10**24));

      assertEq(yamV3.initSupply(), underlying);
    }

    function second_pos_rebase() internal {
      assertTrue(rebaser.getCurrentTWAP() > 105 * 10**16);

      uint256 offset = rebaser.rebaseWindowOffsetSec();
      uint256 interval = rebaser.minRebaseTimeIntervalSec();
      uint256 waitTime;
      if (now % interval > offset) {
        waitTime = (interval - (now % interval)) + offset;
      } else {
        waitTime = offset - (now % interval);
      }
      hevm.warp(now + waitTime);
      uint256 epoch = rebaser.epoch();
      uint256 pre_scalingFactor = yamV3.yamsScalingFactor();

      address yyCRVPool = pairFor(uniFact, address(yamV3), yyCRV);
      uint256 pre_balance = yamV3.balanceOf(me)
                            + yamV3.balanceOf(yyCRVPool)
                            + yamV3.balanceOf(address(user));
      uint256 pre_underlying = yamV3.balanceOfUnderlying(me)
                            + yamV3.balanceOfUnderlying(yyCRVPool)
                            + yamV3.balanceOfUnderlying(address(user));

      /* assertTrue(rebaser.inRebaseWindow()); */
      createYYCRV_YAMPool();
      rebaser.rebase();
      /* assertEq(rebaser.epoch(), epoch + 1);
      assertEq(rebaser.blockTimestampLast(), now);

      // positive rebase
      uint256 balance = yamV3.balanceOf(me)
                            + yamV3.balanceOf(yyCRVPool)
                            + yamV3.balanceOf(address(user));
      uint256 underlying = yamV3.balanceOfUnderlying(me)
                            + yamV3.balanceOfUnderlying(yyCRVPool)
                            + yamV3.balanceOfUnderlying(address(user));

      assertTrue(pre_balance < balance);
      assertTrue(pre_underlying < underlying);

      uint256 scalingFactor = yamV3.yamsScalingFactor();
      assertTrue(scalingFactor > pre_scalingFactor);

      // there can be rounding errors here
      assertTrue(yamV3.totalSupply() - balance < 5);

      assertEq(yamV3.initSupply(), underlying); */
    }

    function getYYCRV() internal {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = yCRV;
        uniRouter.swapExactETHForTokens.value(10**18)(1, path, me, now + 60);
        uint256 balance = IERC20(yCRV).balanceOf(me);
        IERC20(yCRV).approve(yyCRV, uint256(-1));
        YYCRV(yyCRV).deposit(balance);
    }

    function createYAM_ETHPool() internal {
        yamV3.approve(address(uniRouter), uint256(-1));
        uniRouter.addLiquidityETH.value(10**18)(
            address(yamV3),
            100*10**18,
            1,
            1,
            me,
            now + 60
        );
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

    function push_price_down() internal {
        address[] memory path = new address[](2);
        path[0] = address(yamV3);
        path[1] = yyCRV;
        IERC20(yyCRV).approve(address(uniRouter), uint256(-1));
        yamV3.approve(address(uniRouter), uint256(-1));
        uniRouter.swapExactTokensForTokens(
            10*10**18,
            1,
            path,
            me,
            now + 60
        );
    }

    function push_price_up() internal {
        if (IERC20(yyCRV).balanceOf(me) < 10*10**18) {
            getYYCRV();
        }
        address[] memory path = new address[](2);
        path[0] = yyCRV;
        path[1] = address(yamV3);
        IERC20(yyCRV).approve(address(uniRouter), uint256(-1));
        yamV3.approve(address(uniRouter), uint256(-1));
        uniRouter.swapExactTokensForTokens(
            10*10**18,
            1,
            path,
            me,
            now + 60
        );
    }

    function init_twap() internal {
      createYYCRV_YAMPool();
      push_price_up();
      push_price_down();
      hevm.warp(now + 12 hours);
      rebaser.init_twap();
    }

    // calculates the CREATE2 address for a pair without making any external calls
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
