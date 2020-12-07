// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import { IERC20 } from "../../lib/IERC20.sol";
import { Timelock } from "../../governance/TimeLock.sol";
import { IndexStaking } from "./IndexStake.sol";

// Prop for switching from original INDEX incentivizer to new one 
contract Prop4 is YAMv3Test {


    IndexStaking index_onchain;

    IndexStaking old_index_onchain = IndexStaking(0xA940e0541F8b8A40551B28D4C7e37bD85DE426fF);
    IERC20 eth_dpi_lp = IERC20(0x4d5ef58aAc27d99935E5b6B4A6778ff292059991);
    IERC20 index = IERC20(0x0954906da0Bf32d5479e25f46056d22f08464cab);  
  
    function setUp() public {
        setUpCore();
        index_onchain = new IndexStaking(address(timelock),address(reserves));
    }

    event TEST(address yam);

    /**
    * Process:
    * 1. Exit staking on current index staker
    * 2. Get LP tokens from the old index staker
    * 3. Get INDEX tokens from the old index staker
    * 4. Accept gov for new staker
    * 5. Transfer LP tokens to the new index staker
    * 6. Stake on new index staker
    **/
    function test_onchain_prop_4() public {
      assertTrue(false);
      uint256 lpBalance = old_index_onchain.currentStake();
      address[] memory targets = new address[](6);
      uint256[] memory values = new uint256[](6);
      string[] memory signatures = new string[](6);
      bytes[] memory calldatas = new bytes[](6);
      string memory description = "Withdraw from old INDEX staker, start staking on new INDEX staker";


      // -- Exit staking on current staker
      targets[0] = address(old_index_onchain);
      values[0] = 0;
      signatures[0] = "_exitStaking()";
      calldatas[0] = "";

      // -- Get LP tokens from current staker
      targets[1] = address(old_index_onchain);
      values[1] = 0;
      signatures[1] = "_getTokenFromHere(address)";
      calldatas[1] = abi.encode(address(eth_dpi_lp));

      // -- Get INDEX tokens from current staker
      targets[2] = address(old_index_onchain);
      values[2] = 0;
      signatures[2] = "_getTokenFromHere(address)";
      calldatas[2] = abi.encode(address(index));

      // -- Accept gov over new INDEX staker
      targets[3] = address(index_onchain);
      values[3] = 0;
      signatures[3] = "_acceptGov()";
      calldatas[3] = "";

      // -- Transfer LP tokens to the new index staker
      targets[4] = address(reserves);
      values[4] = 0;
      signatures[4] = "oneTimeTransfers(address[],uint256[],address[])";
      address[] memory whos = new address[](1);
      whos[0] = address(index_onchain);
      uint256[] memory amounts = new uint256[](1);
      amounts[0] = uint256(lpBalance);
      address[] memory tokens = new address[](1);
      tokens[0] = address(eth_dpi_lp);
      calldatas[4] = abi.encode(whos, amounts, tokens);

      targets[5] = address(index_onchain);
      signatures[5] = "_stakeCurrentLPBalance()";
      values[5] = 0; 
      calldatas[5] = "";


      yamhelper.getQuorum(yamV3, me);
      yamhelper.bing();

      roll_prop(
          targets,
          values,
          signatures,
          calldatas,
          description
      );

      assertEq(index_onchain.gov(), address(timelock));

      assertEq(index_onchain.currentStake(), lpBalance);


    }
}
