// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import { DualGovernorAlpha } from "../proposal_round_2/YAMGovernorAlphaWithLps.sol";
import { MonthlyAllowance } from "../contributor_monthly_payments/MonthlyAllowance.sol";
import { VestingPool } from "../vesting_pool/VestingPool.sol";

contract Prop3 is YAMv3Test {



    DualGovernorAlpha contributor_gov = DualGovernorAlpha(0xDceC4A3aA84f79249c1b5325a06c1560d202Dd87);
    MonthlyAllowance monthlyAllowance = MonthlyAllowance(0x03A882495Bc616D3a1508211312765904Fb062d1);
    VestingPool vestingPool = VestingPool(0xDCf613db29E4d0B35e7e15e93BF6cc6315eB0b82);

    function setUp() public {
        setUpCore();
        yamhelper.becomeAdmin(address(timelock),0xEDf7C3D4CB2e89506C1469709073025d09D47bDd);
    }



    function test_onchain_prop_3() public {
        assertTrue(false);
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        string[] memory signatures = new string[](4);
        bytes[] memory calldatas = new bytes[](4);
        string memory description = "Accept admin for new governor, set reserves allowance for contributor allowance, add contributor gov as subgov on contributor allowance";

        // -- Main governor accept admin on contributor governor
        targets[0] = address(contributor_gov);
        values[0] = 0;
        signatures[0] = "__acceptAdmin()";
        calldatas[0] = "";

        // -- Main governor set approval for monthly allowance to use yUSD
        targets[1] = address(reserves);
        values[1] = 0;
        signatures[1] = "whitelistWithdrawals(address[],uint256[],address[])";
        address[] memory whos = new address[](1);
        whos[0] = address(monthlyAllowance);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = uint256(-1);
        address[] memory tokens = new address[](1);
        tokens[0] = address(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);
        calldatas[1] = abi.encode(whos, amounts, tokens);

        // -- Accept gov over monthlyAllowance
        targets[2] = address(monthlyAllowance);
        values[2] = 0;
        signatures[2] = "acceptGov()";
        calldatas[2] = ""; 

        // -- Accept gov for vestingPool
        targets[3] = address(vestingPool);
        values[3] = 0;
        signatures[3] = "_acceptGov()";
        calldatas[3] = "";

        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(
            targets,
            values,
            signatures,
            calldatas,
            description
        );
        
        // -- Assert that main governor got guardian of contributor governor
        assertEq(address(timelock), contributor_gov.guardian());
        
        // -- Assert contributor governor timelock is sub gov on monthly allowance contract
        assertTrue(monthlyAllowance.isSubGov(address(contributor_gov.timelock())));

        // -- Assert contributor governor timelock is sub gov on vesting pool contract
        assertTrue(vestingPool.isSubGov(address(contributor_gov.timelock())));
    }
}
