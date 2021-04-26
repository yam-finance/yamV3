// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import {IERC20} from "../../lib/IERC20.sol";
import {UGASJUNFarming} from "../ugas_farming/UGASJUNFarming.sol";
import {USTONKSAPRFarming} from "../ustonks_farming/USTONKSAPRFarming.sol";
import {StreamManager} from "./StreamManager.sol";
import {VestingPool} from "../vesting_pool/VestingPool.sol";
import {UMADistributor} from "./UMADistributor.sol";
import {YAMDistributor} from "./YAMDistributor.sol";

// Prop for March contributor payment and stream setup
contract Prop13 is YAMv3Test {
    StreamManager streamManager = StreamManager(0x0779F8f2da25f25C7C568F4aBcCED8D0e6d48FfC);
    UMADistributor umaDistributor = UMADistributor(0xc4f67FfBDFD80CC8e1CceB1C4F51baC74EeDA71D);
    YAMDistributor yamDistributor = YAMDistributor(0xb1A787A25F614f0c643a27877A0E8f7c363c255a);

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
    
    event GAS_USAGE(uint256 used);
    
    /**
     * Summary:
     * 1. Give one time StreamManager permissions to use VestingPool
     * 2. Give one time StreamManager permissions to use MonthlyAllowance
     * 3. Transfer UMA to UMA distributor
     **/
    function test_onchain_prop_13() public {
        assertTrue(false);

        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        string[] memory signatures = new string[](4);
        bytes[] memory calldatas = new bytes[](4);

        string memory description =
            "Approve StreamManager for VestingPool, approve StreamManager for MonthlyAllowance, transfer UMA to umaDistributor, send YAM to yamDistributor";

        targets[0] = address(vestingPool);
        values[0] = 0;
        signatures[0] = "setSubGov(address,bool)";
        calldatas[0] = abi.encode(streamManager, true);

        targets[1] = address(monthlyAllowance);
        values[1] = 0;
        signatures[1] = "setIsSubGov(address,bool)";
        calldatas[1] = abi.encode(streamManager, true);

        targets[2] = address(reserves);
        values[2] = 0;
        signatures[2] = "oneTimeTransfers(address[],uint256[],address[])";
        address[] memory umaWhos = new address[](1);
        umaWhos[0] = address(umaDistributor);
        uint256[] memory umaAmounts = new uint256[](1);
        umaAmounts[0] = 29673727930140068584843;
        address[] memory umaTokens = new address[](1);
        umaTokens[0] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        calldatas[2] = abi.encode(umaWhos, umaAmounts, umaTokens);

        targets[3] = address(yamV3);
        values[3] = 0;
        signatures[3] = "mint(address,uint256)";
        calldatas[3] = abi.encode(address(yamDistributor), 36102006063173137830825);

        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();
        
        roll_prop(targets, values, signatures, calldatas, description);
        uint256 remainingGas1 = gasleft();
        streamManager.execute();
        emit GAS_USAGE(remainingGas1 - gasleft());
        remainingGas1 = gasleft();
        umaDistributor.execute();
        emit GAS_USAGE(remainingGas1 - gasleft());
        remainingGas1 = gasleft();
        yamDistributor.execute();
        emit GAS_USAGE(remainingGas1 - gasleft());
    }
}
