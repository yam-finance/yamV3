// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import { DualGovernorAlpha } from "../proposal_round_2/YAMGovernorAlphaWithLps.sol";
import { MonthlyAllowance } from "../contributor_monthly_payments/MonthlyAllowance.sol";
import { VestingPool } from "../vesting_pool/VestingPool.sol";
import { IERC20 } from "../../lib/IERC20.sol";
import { Timelock } from "../../governance/TimeLock.sol";

contract Prop3 is YAMv3Test {



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
        address[] memory targets = new address[](6);
        uint256[] memory values = new uint256[](6);
        string[] memory signatures = new string[](6);
        bytes[] memory calldatas = new bytes[](6);
        string memory description = "Accept admin for new governor, set reserves allowance for contributor allowance, add contributor gov as subgov on contributor allowance";

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
        address[] memory whos = new address[](1);
        whos[0] = address(monthlyAllowance);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = uint256(-1);
        address[] memory tokens = new address[](1);
        tokens[0] = address(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);
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

    }
}
