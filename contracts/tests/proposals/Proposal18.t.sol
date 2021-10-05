// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../../tests/test_tests/base.t.sol";
import {IERC20} from "../../lib/IERC20.sol";
import {Proposal18} from "../../proposals/proposal_round_18/Proposal18.sol";
import {UGAS1221Farming} from "../ugas_farming/UGAS1221Farming.sol";
import {USTONKSSEPTFarming} from "..//ustonks_farming/USTONKSSEPTFarming.sol";
import {UPUNKS1221Farming} from "..//upunks_farming/UPUNKS1221Farming.sol";
import {YAMDelegate3} from "../../token/YAMDelegate3.sol";

// Prop for July contributor payment and stream setup
contract Prop18 is YAMv3Test {
    Proposal18 private proposal = Proposal18(0xffA396b7490dDAa4230B34aF365620Fa1802c4B3);

    UGAS1221Farming internal constant UGAS_FARMING_JUN = UGAS1221Farming(0xd25b60D3180Ca217FDf1748c86247A81b1aa43d6);
    UGAS1221Farming internal UGAS_FARMING_SEPT = UGAS1221Farming(0x54837096585faB2E45B9a9b0b38B542136d136D5);

    USTONKSSEPTFarming internal USTONKS_FARMING_SEPT_1 = USTONKSSEPTFarming(0x9789204c43bbc03E9176F2114805B68D0320B31d);
    USTONKSSEPTFarming internal USTONKS_FARMING_SEPT_2 = USTONKSSEPTFarming(0xdb0742bdBd7876344046f0E7Ca8bC769e85Fdd01);

    UPUNKS1221Farming internal UPUNKS_FARMING_SEPT = UPUNKS1221Farming(0x0c9D03B5CDa39184f62C7b05e77408C06A963FE6);

    address internal NEW_YAM_IMPLEMENTATION = 0x27C5736b49B89d4765d03734a0a51c461F09672d;

    address internal constant TREASURY_MULTISIG = 0x744D16d200175d20E6D8e5f405AEfB4EB7A962d1;

    function setUp() public {
        setUpCore();
    }

    event TEST(
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        string description
    );

    event TEST_NUM(uint256 used);

    /**
     * Summary:
     * 1. Give Proposal permissions to use index staking contract and Yam's synth farming contracts
     * 2. Send YAM to distributor - uPUNK rewards payout
     * 3. Send USDC to distributor - monthly contributor payout
     * 4. Delegate INDEX to Feddas
     **/
    function test_onchain_prop_18() public {
        // Assert false so it posts the verbose version. Comment this out allow the test to actually succeed

        address[] memory targets = new address[](8);
        uint256[] memory values = new uint256[](8);
        string[] memory signatures = new string[](8);
        bytes[] memory calldatas = new bytes[](8);

        string
            memory description = "Setup proposol as sub gov on indexStaking/vestingPool and uGas/uStonks/uPunks farming, whitelist withdrawals for farming/lping/multisig funding, update YAM implementation to add burning capability";

        // -- Set proposal as sub gov for indexStaking
        targets[0] = address(indexStaking);
        signatures[0] = "setIsSubGov(address,bool)";
        calldatas[0] = abi.encode(address(proposal), true);



        // -- Set proposal as sub gov for UGAS June Farming
        targets[1] = address(UGAS_FARMING_JUN);
        signatures[1] = "setIsSubGov(address,bool)";
        calldatas[1] = abi.encode(address(proposal), true);

        // -- Set proposal as sub gov for UGAS Sept Farming
        targets[2] = address(UGAS_FARMING_SEPT);
        signatures[2] = "setIsSubGov(address,bool)";
        calldatas[2] = abi.encode(address(proposal), true);

        // -- Set proposal as sub gov for old USTONKS Sept Farming
        targets[3] = address(USTONKS_FARMING_SEPT_1);
        signatures[3] = "setIsSubGov(address,bool)";
        calldatas[3] = abi.encode(address(proposal), true);

        // -- Set proposal as sub gov for new USTONKS Sept Farming
        targets[4] = address(USTONKS_FARMING_SEPT_2);
        signatures[4] = "setIsSubGov(address,bool)";
        calldatas[4] = abi.encode(address(proposal), true);

        // -- Set proposal as sub gov for new USTONKS Sept Farming
        targets[5] = address(UPUNKS_FARMING_SEPT);
        signatures[5] = "setIsSubGov(address,bool)";
        calldatas[5] = abi.encode(address(proposal), true);

        // -- Whitelist proposal to withdraw usdc. whitelist Swapper to withdraw WETH, SUSHI, and DPI
        targets[6] = address(reserves);
        signatures[6] = "whitelistWithdrawals(address[],uint256[],address[])";
        address[] memory whos = new address[](10);
        uint256[] memory amounts = new uint256[](10);
        address[] memory tokens = new address[](10);

        whos[0] = address(proposal);
        amounts[0] = uint256(-1);
        tokens[0] = address(SUSHI);

        whos[1] = address(proposal);
        amounts[1] = uint256(-1);
        tokens[1] = address(YAM_HOUSE);

        whos[2] = address(UGAS_FARMING_SEPT);
        amounts[2] = uint256(-1);
        tokens[2] = address(WETH);

        whos[3] = address(USTONKS_FARMING_SEPT_2);
        amounts[3] = uint256(-1);
        tokens[3] = address(USDC);

        whos[4] = address(UPUNKS_FARMING_SEPT);
        amounts[4] = uint256(-1);
        tokens[4] = address(WETH);

        whos[5] = address(indexStaking);
        amounts[5] = uint256(-1);
        tokens[5] = address(WETH);

        whos[6] = address(indexStaking);
        amounts[6] = uint256(-1);
        tokens[6] = address(DPI);

        whos[7] = address(proposal);
        amounts[7] = uint256(26624383201800000000);
        tokens[7] = address(WETH);

        whos[8] = address(proposal);
        amounts[8] = uint256(-1);
        tokens[8] = address(USDC);

        whos[9] = address(proposal);
        amounts[9] = uint256(-1);
        tokens[9] = address(yamV3);

        calldatas[6] = abi.encode(whos, amounts, tokens);

        // -- Set Yam Implementation
        targets[7] = address(yamV3);
        signatures[7] = "_setImplementation(address,bool,bytes)";
        calldatas[7] = abi.encode(NEW_YAM_IMPLEMENTATION,false,bytes(""));

        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description);

        executeProposal();
        tests();
        testWithdrawals();
    }

    function executeProposal() internal {
        proposal.executeStepOne();
        yamhelper.ff(12 hours);

        UGAS_FARMING_SEPT.update_twap();
        UGAS_FARMING_JUN.update_twap();
        USTONKS_FARMING_SEPT_1.update_twap();
        USTONKS_FARMING_SEPT_2.update_twap();
        UPUNKS_FARMING_SEPT.update_twap();
        indexStaking.update_twap();
        yamhelper.ff(61 minutes);

        UGAS_FARMING_SEPT.enter();
        UGAS_FARMING_JUN.exit();
        USTONKS_FARMING_SEPT_1.exit();
        USTONKS_FARMING_SEPT_2.enter();
        UPUNKS_FARMING_SEPT.enter();

        indexStaking.update_twap();
        indexStaking.stake();

        proposal.executeStepTwo();


    }

    function tests() internal {
        // Assert the yamV3 supply should be reduced
        assertTrue(IERC20(address(yamV3)).totalSupply() < 15000000 * (10**18));
        // Assert reserves have the yUSDC we should have
        assertTrue(IERC20(address(yUSDC)).balanceOf(address(reserves)) > 390000 * (10**6));
        // Assert reserves have the xSUSHI we should have
        assertTrue(IERC20(address(xSUSHI)).balanceOf(address(reserves)) > 0);
        // Assert multisig balances are correct
        assertEq(IERC20(address(USDC)).balanceOf(TREASURY_MULTISIG), 100817846121);
        assertEq(IERC20(address(WETH)).balanceOf(TREASURY_MULTISIG), 3000000000000000000);
        assertEq(IERC20(address(yamV3)).balanceOf(TREASURY_MULTISIG), 34989830191026533128789);
    }

    // Creates and executes 2nd proposal that withdraws all assets from synth farming and dpi/eth pooling, testing that they work as expected
    // Not strictly necessary, as withdrawals are tested elsewhere, but just as an extra sanity check 
    function testWithdrawals() internal {
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        string[] memory signatures = new string[](4);
        bytes[] memory calldatas = new bytes[](4);

        string
            memory description = "Exit farming and LPing";

        // -- Set proposal as sub gov for indexStaking
        targets[0] = address(UGAS_FARMING_SEPT);
        signatures[0] = "_approveExit()";
        calldatas[0] = "";


        // -- Set proposal as sub gov for indexStaking
        targets[1] = address(USTONKS_FARMING_SEPT_2);
        signatures[1] = "_approveExit()";
        calldatas[1] = "";

        // -- Set proposal as sub gov for indexStaking
        targets[2] = address(UPUNKS_FARMING_SEPT);
        signatures[2] = "_approveExit()";
        calldatas[2] = "";

        // -- Set proposal as sub gov for indexStaking
        targets[3] = address(indexStaking);
        signatures[3] = "_exitAndApproveGetUnderlying()";
        calldatas[3] = "";

        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description);

        // Try withdrawing UGAS, USTONKS, and UPUNKS
        UGAS_FARMING_SEPT.update_twap();
        USTONKS_FARMING_SEPT_2.update_twap();
        UPUNKS_FARMING_SEPT.update_twap();
        yamhelper.ff(61 minutes);
        UGAS_FARMING_SEPT.exit();
        USTONKS_FARMING_SEPT_2.exit();
        UPUNKS_FARMING_SEPT.exit();
        indexStaking.update_twap();
        indexStaking.getUnderlying();

        // Assert we have the WETH we should have
        assertTrue(IERC20(WETH).balanceOf(address(reserves)) > 770 * (10**18));
        // Assert we have the DPI we should have
        assertTrue(IERC20(DPI).balanceOf(address(reserves)) > 4400 * (10**18));
        // Assert we have the USDC we should have
        assertTrue(IERC20(USDC).balanceOf(address(reserves)) > 987000 * (10**6));
    }
}
