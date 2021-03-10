// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import {IERC20} from "../../lib/IERC20.sol";
import {UGASJUNFarming} from "../ugas_farming/UGASJUNFarming.sol";
import {USTONKSAPRFarming} from "../ustonks_farming/USTONKSAPRFarming.sol";
import {StreamManager} from "./StreamManager.sol";
import {VestingPool} from "../vesting_pool/VestingPool.sol";

// Prop for December contributor payment and stream setup
contract Prop9 is YAMv3Test {
    address treasuryManager = 0xe7481861d4855a4515fbcbEfd2a59EFF601D6d6E;
    UGASJUNFarming marFarming =
        UGASJUNFarming(0xffb607418dBEaB7A888e079A34Be28A30d8E1DE2);
    UGASJUNFarming junFarming =
        UGASJUNFarming(0xd25b60D3180Ca217FDf1748c86247A81b1aa43d6);
    USTONKSAPRFarming stonksFarming =
        USTONKSAPRFarming(0xD2CB51A362431B6C88336B08AA60B8e8637D21d7);
    StreamManager streamManager = StreamManager(0xd8c745572e267a4f4dFD519aaf9f46480c5F20FF);

    VestingPool pool = VestingPool(0xDCf613db29E4d0B35e7e15e93BF6cc6315eB0b82);

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

    /**
     * Summary:
     * 1. Accept
     * 2. Give BulkPayer permissions to create streams
     * 3. Execute BulkPayer, pays out past vested YAM and sets up ongoing streams
     * 4. Set new Governor as pending admin
     **/
    function test_onchain_prop_12() public {
        assertTrue(false);

        address[] memory targets = new address[](7);
        uint256[] memory values = new uint256[](7);
        string[] memory signatures = new string[](7);
        bytes[] memory calldatas = new bytes[](7);

        string memory description =
            "Exit uGAS-MAR, enter uGAS-JUN, enter uSTONKS-JUN";

        // -- Exit uGAS-MAR farming
        targets[0] = address(marFarming);
        values[0] = 0;
        signatures[0] = "_approveExit()";
        calldatas[0] = "";

        // -- Enter uGAS-JUN farming
        targets[1] = address(junFarming);
        values[1] = 0;
        signatures[1] = "_approveEnter()";
        calldatas[1] = "";

        // -- Enter uSTONKS APR farming
        targets[2] = address(stonksFarming);
        values[2] = 0;
        signatures[2] = "_approveEnter()";
        calldatas[2] = "";

        // -- Send yUSD to uSTONKS APR farming contract, send UMA rewards
        targets[3] = address(reserves);
        signatures[3] = "oneTimeTransfers(address[],uint256[],address[])";
        address[] memory whos = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory tokens = new address[](1);

        whos[0] = address(stonksFarming);
        amounts[0] = uint256((910000 * (10**18) * 79) / 100);
        tokens[0] = yyCRV;
        calldatas[3] = abi.encode(whos, amounts, tokens);

        // -- Approve uGAS-JUN farming contract to withdraw weth
        targets[4] = address(reserves);
        signatures[4] = "whitelistWithdrawals(address[],uint256[],address[])";
        address[] memory whos2 = new address[](1);
        uint256[] memory amounts2 = new uint256[](1);
        address[] memory tokens2 = new address[](1);

        whos2[0] = address(junFarming);
        amounts2[0] = uint256(-1);
        tokens2[0] = address(WETH);
        calldatas[4] = abi.encode(whos2, amounts2, tokens2);

        // // -- Distribute UMA rewards
        address[] memory whosUMA = new address[](13);
        uint256[] memory amountsUMA = new uint256[](13);
        address[] memory tokensUMA = new address[](13);
        populateUMARewardsInfo(whosUMA, amountsUMA, tokensUMA);

        targets[5] = address(reserves);
        values[5] = 0;
        signatures[5] = "oneTimeTransfers(address[],uint256[],address[])";
        calldatas[5] = abi.encode(whosUMA, amountsUMA, tokensUMA);


        targets[6] = address(vestingPool);
        values[6] = 0;
        signatures[6] = "setSubGov(address,bool)";
        calldatas[6] = abi.encode(streamManager,true);

        emit TEST(targets, values, signatures, calldatas, description);
        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description);

        marFarming.update_twap();
        junFarming.update_twap();
        stonksFarming.update_twap();
        yamhelper.ff(60 * 61);
        marFarming.exit();
        junFarming.enter();
        stonksFarming.enter();
        streamManager.execute();

        // roll_exit_prop();

        // junFarming.update_twap();
        // stonksFarming.update_twap();
        // yamhelper.ff(60 * 61);
        // junFarming.exit();
        // stonksFarming.exit();
    }

    function populateUMARewardsInfo(
        address[] memory whosUMA,
        uint256[] memory amountsUMA,
        address[] memory tokensUMA
    ) internal {
        whosUMA[0] = 0xA77Ac35AA49536Cd0539798eEB2Fee1B72f64679;
        whosUMA[1] = 0xdD395050aC923466D3Fa97D41739a4ab6b49E9F5;
        whosUMA[2] = 0x7c21d373E369B6ecC9D418180A07E83DE3493Df7;
        whosUMA[3] = 0x53c91f33e4dA805d04DCe861C536fA1674e7334d;
        whosUMA[4] = 0xa6584b95EA4E9018b1F377dad99448EC478a150f;
        whosUMA[5] = 0x7FC6bb05ffaD5936D08F097FAb13d2eF2Ff8D75C;
        whosUMA[6] = 0xffb607418dBEaB7A888e079A34Be28A30d8E1DE2;
        whosUMA[7] = 0x6A05c29Ff98c54013E629aa6D1698f43D59724CF;
        whosUMA[8] = 0xf58CB5e797FAeF35102a756CF8bAc25991DC2838;
        whosUMA[9] = 0x8d5F05270da470e015b67Ab5042BDbE2D2FEFB48;
        whosUMA[10] = 0x3432F2E175B57c904058A90528201280414eCce7;
        whosUMA[11] = 0xA8612C28C8f878Ec80f8A6630796820Ae8C7690E;
        whosUMA[12] = 0x3B2cba3423199f73924AD609fa8EeC504E1FaC1f;

        amountsUMA[0] = 12337037951446657008;
        amountsUMA[1] = 1161781240945617067020;
        amountsUMA[2] = 20002245413864064730;
        amountsUMA[3] = 19683624887786493074;
        amountsUMA[4] = 120155138769375086739;
        amountsUMA[5] = 5104929909459024502;
        amountsUMA[6] = 763101265318097645247;
        amountsUMA[7] = 5629782641358900693;
        amountsUMA[8] = 219586632904543178;
        amountsUMA[9] = 2690894077957054054;
        amountsUMA[10] = 2773502060890580361;
        amountsUMA[11] = 6038052118407201000;
        amountsUMA[12] = 10536590952142476922;

        tokensUMA[0] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[1] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[2] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[3] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[4] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[5] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[6] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[7] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[8] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[9] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[10] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[11] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[12] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
    }

    function roll_exit_prop() internal {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        string[] memory signatures = new string[](2);
        bytes[] memory calldatas = new bytes[](2);

        string memory description =
            "Approve exiting UGAS farming and USTONKS farming";

        // -- Approve exit for ugas farming
        targets[0] = address(junFarming);
        signatures[0] = "_approveExit()";
        calldatas[0] = "";

        // -- Approve exit for ustonks farming
        targets[0] = address(stonksFarming);
        signatures[0] = "_approveExit()";
        calldatas[0] = "";

        emit TEST(targets, values, signatures, calldatas, description);
        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description);
    }
}
