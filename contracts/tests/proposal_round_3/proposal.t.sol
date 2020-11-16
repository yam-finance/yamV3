// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import { DualGovernorAlpha } from "../proposal_round_2/YAMGovernorAlphaWithLps.sol";
import { MonthlyAllowance } from "../contributor_monthly_payments/MonthlyAllowance.sol";
import { VestingPool } from "../vesting_pool/VestingPool.sol";
import { IERC20 } from "../../lib/IERC20.sol";
import { Timelock } from "../../governance/TimeLock.sol";
import { IndexStaking } from "../index_staking/indexStake.sol";

contract Prop3 is YAMv3Test {


    IndexStaking index_onchain = IndexStaking(0xA940e0541F8b8A40551B28D4C7e37bD85DE426fF);
    DualGovernorAlpha contributor_gov = DualGovernorAlpha(0xDceC4A3aA84f79249c1b5325a06c1560d202Dd87);
    MonthlyAllowance monthlyAllowance = MonthlyAllowance(0x03A882495Bc616D3a1508211312765904Fb062d1);
    VestingPool vestingPool = VestingPool(0xDCf613db29E4d0B35e7e15e93BF6cc6315eB0b82);
    address yamLogic3 = 0x405d5F5b76c94ebc26A28E56961c63cd9E743Af2;

    function setUp() public {
        setUpCore();
        yamhelper.becomeAdmin(address(timelock),0xEDf7C3D4CB2e89506C1469709073025d09D47bDd);
    }

    event TEST(address yam);

    function test_onchain_prop_3() public {
      assertTrue(false);
      address[] memory targets = new address[](8);
      uint256[] memory values = new uint256[](8);
      string[] memory signatures = new string[](8);
      bytes[] memory calldatas = new bytes[](8);
      string memory description = "Accept admin for new governor, set reserves allowance for contributor & Index staking allowance, add contributor gov as subgov on contributor allowance, allow staking DPI/ETH";


      // -- Accept admin on contributor governor (for taking control of Timelock)
      targets[0] = address(contributor_gov);
      values[0] = 0;
      signatures[0] = "__acceptAdmin()";
      calldatas[0] = "";

      // -- Accept gov over vesting pool
      targets[1] = address(vestingPool);
      values[1] = 0;
      signatures[1] = "_acceptGov()";
      calldatas[1] = "";

      // -- Accept gov over monthlyAllowance
      targets[2] = address(monthlyAllowance);
      values[2] = 0;
      signatures[2] = "acceptGov()";
      calldatas[2] = "";

      // -- Set approval on reserves for monthly allowance contract to use yUSD
      targets[3] = address(reserves);
      values[3] = 0;
      signatures[3] = "whitelistWithdrawals(address[],uint256[],address[])";
      address[] memory whos = new address[](3);
      whos[0] = address(monthlyAllowance);
      whos[1] = address(index_onchain);
      whos[2] = address(index_onchain);
      uint256[] memory amounts = new uint256[](3);
      amounts[0] = uint256(-1);
      amounts[1] = uint256(-1);
      amounts[2] = uint256(-1);
      address[] memory tokens = new address[](3);
      tokens[0] = address(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);
      tokens[1] = address(WETH);
      tokens[2] = address(DPI);
      calldatas[3] = abi.encode(whos, amounts, tokens);

      // -- Set yam imlementation
      targets[4] = address(yamV3);
      values[4] = 0;
      signatures[4] = "_setImplementation(address,bool,bytes)";
      calldatas[4] = abi.encode(yamLogic3,false,"");

      // -- Mint YAM to vesting pool
      targets[5] = address(yamV3);
      values[5] = 0;
      signatures[5] = "mintUnderlying(address,uint256)";
      calldatas[5] = abi.encode(address(vestingPool),100000 * (10**24));

      // -- Accept gov over monthlyAllowance
      targets[6] = address(index_onchain);
      values[6] = 0;
      signatures[6] = "_acceptGov()";
      calldatas[6] = "";

      targets[7] = address(index_onchain);
      signatures[7] = "_approveStakingFromReserves(bool,uint256)";
      uint256 weth_bal = IERC20(WETH).balanceOf(address(reserves));
      calldatas[7] = abi.encode(
          false, // WETH is token 1 and we have less of it
          weth_bal
      );

      yamhelper.getQuorum(yamV3, me);
      yamhelper.bing();

      roll_prop(
          targets,
          values,
          signatures,
          calldatas,
          description
      );

      // -- Assert contributor timelock had admin set properly
      address payable wallet = address(uint160(address(contributor_gov.timelock())));
      assertEq(address(contributor_gov), Timelock(wallet).admin());

      // -- Assert governor timelock for vestingPool
      assertEq(vestingPool.gov(), address(governor.timelock()));

      // -- Assert governor timelock for monthlyAllowance
      assertEq(monthlyAllowance.gov(), address(governor.timelock()));

      // -- Assert allowance set for monthlyAllowance
      assertEq(IERC20(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c).allowance(address(reserves), address(monthlyAllowance)), uint256(-1));

      // -- Assert implementation set for yam
      assertEq(yamV3.implementation(), yamLogic3);

      // -- Assert that the vesting pool got the correct amount of YAM
      assertEq(yamV3.balanceOfUnderlying(address(vestingPool)), 100000 * (10**24));

      assertEq(index_onchain.gov(), address(timelock));

      assertEq(index_onchain.purchase_token(), DPI);
      assertEq(index_onchain.sell_token(), WETH);
      assertEq(index_onchain.sell_amount(), weth_bal);
      yamhelper.ff(60*60);

      index_onchain.update_twap();

      assertEq(index_onchain.bounds(), 0, "bounds");
      assertEq(index_onchain.bounds_max(), 0, "bounds_max");

      uint256 quoted;
      (uint256 reserve0, uint256 reserve1, ) = UniswapPair(index_onchain.uniswap_pair1()).getReserves();
      if (index_onchain.saleTokenIs0()) {
        quoted = index_onchain.quote(reserve1, reserve0);
      } else {
        quoted = index_onchain.quote(reserve0, reserve1);
      }
      assertEq(quoted, 0, "quoted");
      index_onchain.stake();

    }
}
