// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import {IERC20} from "../../lib/IERC20.sol";
import {SetJoiner} from "./SetJoiner.sol";
import {UMAFarmingMar} from "../uma_farming/UMAFarmingMar.sol";

// Prop for December contributor payment and stream setup
contract Prop9 is YAMv3Test {
    SetJoiner setJoiner = SetJoiner(0xA83fB84444a4D4Ce942df85ED8aa666D440CD5df);
    address treasuryManager = 0xe7481861d4855a4515fbcbEfd2a59EFF601D6d6E;
    UMAFarmingMar febMining = UMAFarmingMar(
        0xc0AE1e1e172ECD4C56fD8043FD5Afe5a473E9835
    );
    UMAFarmingMar marMining = UMAFarmingMar(
        0xffb607418dBEaB7A888e079A34Be28A30d8E1DE2
    );

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
    function test_onchain_prop_9() public {
        assertTrue(false);

        address[] memory targets = new address[](8);
        uint256[] memory values = new uint256[](8);
        string[] memory signatures = new string[](8);
        bytes[] memory calldatas = new bytes[](8);


            string memory description
         = "Accept gov for yamHOUSE treasury manager, deposit 810k yUSD to yamHOUSE, withdraw from feb uGAS, deposit to mar uGAS, distribute UMA rewards";

        // -- Accept gov over treasuryManager
        targets[0] = address(treasuryManager);
        values[0] = 0;
        signatures[0] = "_acceptGov()";
        calldatas[0] = "";

        // -- Transfer 810k (~$1mm) yUSD to setJoiner
        address[] memory whos = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory tokens = new address[](1);
        whos[0] = address(setJoiner);
        amounts[0] = 810000 * (10**18);
        tokens[0] = yyCRV;

        targets[1] = address(reserves);
        values[1] = 0;
        signatures[1] = "oneTimeTransfers(address[],uint256[],address[])";
        calldatas[1] = abi.encode(whos, amounts, tokens);

        // -- Execute SetJoiner, depositing 810k yUSD to yamHOUSE, sending minted yamHOUSE back to reserves
        targets[2] = address(setJoiner);
        values[2] = 0;
        signatures[2] = "execute()";
        calldatas[2] = "";

        // -- Exit Feb uGAS
        targets[3] = address(febMining);
        values[3] = 0;
        signatures[3] = "_approveExit()";
        calldatas[3] = "";

        targets[4] = address(reserves);
        signatures[4] = "whitelistWithdrawals(address[],uint256[],address[])";
        whos[0] = address(marMining);
        amounts[0] = uint256(-1);
        tokens[0] = address(WETH);
        calldatas[4] = abi.encode(whos, amounts, tokens);

        // -- Accept gov over marMining
        targets[5] = address(marMining);
        values[5] = 0;
        signatures[5] = "_acceptGov()";
        calldatas[5] = "";

        // -- Enter Mar uGAS
        targets[6] = address(marMining);
        values[6] = 0;
        signatures[6] = "_approveEnter()";
        calldatas[6] = "";

        // -- Distribute UMA rewards
        address[] memory whosUMA = new address[](18);
        uint256[] memory amountsUMA = new uint256[](18);
        address[] memory tokensUMA = new address[](18);
        populateUMARewardsInfo(whosUMA, amountsUMA, tokensUMA);
        
        targets[7] = address(reserves);
        values[7] = 0;
        signatures[7] = "oneTimeTransfers(address[],uint256[],address[])";
        calldatas[7] = abi.encode(whosUMA,amountsUMA,tokensUMA);

        emit TEST(targets, values, signatures, calldatas, description);
        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description);

        assertEq(
            IERC20(YAM_HOUSE).balanceOf(address(reserves)),
            810000 * (10**18)
        );

        febMining.update_twap();
        marMining.update_twap();
        yamhelper.ff(60 * 61);
        febMining.exit();
        marMining.enter();
    }

    function populateUMARewardsInfo(
        address[] memory whosUMA,
        uint256[] memory amountsUMA,
        address[] memory tokensUMA
    ) internal {
        whosUMA[0] = 0xA77Ac35AA49536Cd0539798eEB2Fee1B72f64679;
        whosUMA[1] = 0x8d5F05270da470e015b67Ab5042BDbE2D2FEFB48;
        whosUMA[2] = 0xEC3281124d4c2FCA8A88e3076C1E7749CfEcb7F2;
        whosUMA[3] = 0xdD395050aC923466D3Fa97D41739a4ab6b49E9F5;
        whosUMA[4] = 0x3432F2E175B57c904058A90528201280414eCce7;
        whosUMA[5] = 0x653d63E4F2D7112a19f5Eb993890a3F27b48aDa5;
        whosUMA[6] = 0xA8612C28C8f878Ec80f8A6630796820Ae8C7690E;
        whosUMA[7] = 0x7c21d373E369B6ecC9D418180A07E83DE3493Df7;
        whosUMA[8] = 0x6f5641eF2c90B4fe8C63232c8dF5972CA3b17dDd;
        whosUMA[9] = 0xf307077Dd0e27A382E93f2e3d13A9C6584582332;
        whosUMA[10] = 0xd165164cbAb65004Da73C596712687C16b981274;
        whosUMA[11] = 0xEb91FbD00444FcB9078030933A9beaB5a8C731FC;
        whosUMA[12] = 0xB8bDffa3De9939CeD80769B0B9419746a49F7Aa5;
        whosUMA[13] = 0xb43923634fF5556E8188886b24EDB8f17204B25c;
        whosUMA[14] = 0x58c405fa4bd91A46fDB5821C1f5A1758845Eed0d;
        whosUMA[15] = 0x97f0978c18DE9B61840d4627040AEA796090343F;
        whosUMA[16] = 0x284F15960617ec1b21E150CF611770D2cE8a4A88;
        whosUMA[17] = 0x844160aa1DD2A140084a3ED91FCba41E508fA233;

        amountsUMA[0] = 17749573141206385963;
        amountsUMA[1] = 5242194059343386592;
        amountsUMA[2] = 26347155858442518854;
        amountsUMA[3] = 1820622450010663817330;
        amountsUMA[4] = 5608193910861053526;
        amountsUMA[5] = 5429587626180876621;
        amountsUMA[6] = 1868213052442985171;
        amountsUMA[7] = 6776392250617324907;
        amountsUMA[8] = 365118207841109721;
        amountsUMA[9] = 5756143771414045872;
        amountsUMA[10] = 386921949241325050238;
        amountsUMA[11] = 387665741564325472;
        amountsUMA[12] = 25524613448704614717;
        amountsUMA[13] = 33383974072007752474;
        amountsUMA[14] = 5462711587653981818;
        amountsUMA[15] = 7473838340700710090;
        amountsUMA[16] = 3251352735389561044;
        amountsUMA[17] = 266697514115184127;

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
        tokensUMA[13] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[14] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[15] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[16] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
        tokensUMA[17] = 0x04Fa0d235C4abf4BcF4787aF4CF447DE572eF828;
    }
}
