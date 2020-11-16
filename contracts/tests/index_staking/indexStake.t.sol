pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import { IndexStaking } from "./indexStake.sol";

contract IndexStakeTest is YAMv3Test {
    IndexStaking index;

    function setUp() public {
        setUpCore();
        index = new IndexStaking(address(timelock), address(reserves));
        // get reserves_gov, approve withdraws
        yamhelper.write_flat(address(reserves), "gov()", me);
        address[] memory whos = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        address[] memory tokens = new address[](2);
        whos[0] = address(index);
        whos[1] = address(index);
        amounts[0] = uint256(-1);
        amounts[1] = uint256(-1);
        tokens[0] = address(WETH);
        tokens[1] = address(DPI);
        reserves.whitelistWithdrawals(whos, amounts, tokens);
    }

    function test_index_stake() public {
        stake();
    }

    function test_index_stake_manipulation() public {
        assertEq(index.gov(), me);
        index._approveStakingFromReserves(
          false, // weth limited, which is token1
          IERC20(address(WETH)).balanceOf(address(reserves)) // entire weth balance
        );
        yamhelper.ff(60*60);

        index.update_twap();

        set_uni_price(
            index.lp(),
            DPI,
            10**18
        );

        assertEq(index.bounds(), 0, "bounds");
        assertEq(index.bounds_max(), 0, "bounds_max");

        uint256 quoted;
        (uint256 reserve0, uint256 reserve1, ) = UniswapPair(index.uniswap_pair1()).getReserves();
        if (index.saleTokenIs0()) {
          quoted = index.quote(reserve1, reserve0);
        } else {
          quoted = index.quote(reserve0, reserve1);
        }
        assertEq(quoted, 0, "quoted");
        index.stake();
    }
    function test_index_getUnderlying() public {
        stake();

        index._exitAndApproveGetUnderlying();
        yamhelper.ff(60*60);

        index.update_twap();
        index.getUnderlying();
    }
    function test_index__stakeCurrentLPBalance() public {
        stake();
        index._exitStaking();
        index._stakeCurrentLPBalance();
    }

    function test_index__approveStakingFromReserves() public {
        approveStaking();
    }
    function test_index__exitAndApproveGetUnderlying() public {
        stake();
        index._exitAndApproveGetUnderlying();
        yamhelper.ff(60*60);

        index.update_twap();

        assertEq(index.bounds(), 0, "bounds");
        assertEq(index.bounds_max(), 0, "bounds_max");

        uint256 quoted;
        (uint256 reserve0, uint256 reserve1, ) = UniswapPair(index.uniswap_pair1()).getReserves();
        if (index.saleTokenIs0()) {
          quoted = index.quote(reserve1, reserve0);
        } else {
          quoted = index.quote(reserve0, reserve1);
        }
        assertEq(quoted, 0, "quoted");
        index.getUnderlying();
    }
    function test_index__exitStaking() public {
        stake();
        uint256 bal = index.currentStake();
        index._exitStaking();
        assertEq(IERC20(index.lp()).balanceOf(address(index)), bal);
    }
    function test_index__exitStakingEmergency() public {
        stake();
        index._exitStakingEmergency();
    }
    function test__exitStakingEmergencyAndApproveGetUnderlying() public {
        stake();
        index._exitStakingEmergencyAndApproveGetUnderlying();
        yamhelper.ff(60*60);

        index.update_twap();

        assertEq(index.bounds(), 0, "bounds");
        assertEq(index.bounds_max(), 0, "bounds_max");

        uint256 quoted;
        (uint256 reserve0, uint256 reserve1, ) = UniswapPair(index.uniswap_pair1()).getReserves();
        if (index.saleTokenIs0()) {
          quoted = index.quote(reserve1, reserve0);
        } else {
          quoted = index.quote(reserve0, reserve1);
        }
        assertEq(quoted, 0, "quoted");
        index.getUnderlying();
    }
    function test_index__getTokenFromHere() public {
    }

    function approveStaking() public {
        index._approveStakingFromReserves(
          false, // weth limited, which is token1
          IERC20(address(WETH)).balanceOf(address(reserves)) // entire weth balance
        );
        yamhelper.ff(60*60);

        index.update_twap();

        assertEq(index.bounds(), 0, "bounds");
        assertEq(index.bounds_max(), 0, "bounds_max");

        uint256 quoted;
        (uint256 reserve0, uint256 reserve1, ) = UniswapPair(index.uniswap_pair1()).getReserves();
        if (index.saleTokenIs0()) {
          quoted = index.quote(reserve1, reserve0);
        } else {
          quoted = index.quote(reserve0, reserve1);
        }
        assertEq(quoted, 0, "quoted");
    }

    function stake() public {
        approveStaking();
        index.stake();
    }
}
