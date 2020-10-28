// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";

contract ContribPayout is YAMv3Test {


    function setUp() public {
        setUpCore();
    }

    function test_payout_prop() public {
        address[] memory whos = new address[](28);
        uint256[] memory amounts = new uint256[](28);
        address[] memory tokens = new address[](28);
        whos[0] = address(0x4a29e88cEA7e1505DB9b6491C749Fb5d6d595265);
        whos[1] = address(0xC3edCBe0F93a6258c3933e86fFaA3bcF12F8D695);
        whos[2] = address(0x69CF70d4F6181faFd047466470Ba2119De0bCac4);
        whos[3] = address(0xA664A9cc53b9d02A9D9796Ec24C1BA958bD5aA44);
        whos[4] = address(0xDc07A76F00A16d98114097057B38Da3325A91b66);
        whos[5] = address(0xF317172D2acF09511376CE54642fC09DF0239068);
        whos[6] = address(0xEC3281124d4c2FCA8A88e3076C1E7749CfEcb7F2);
        whos[7] = address(0x3F50f328ED67860f4ef0C11552Cf4b3329dee1b5);
        whos[8] = address(0xa6D8c7A9a4567FC3E4519c4163981aC122b9f88b);
        whos[9] = address(0x7cF090168D67EA6626C590a0b708a8B7D0656dEF);
        whos[10] = address(0x9098eab0a361D29Ea5c4b5d9d1f50694ac0E9e78);
        whos[11] = address(0x83f663823484fA63A036FCe7c3cF1C09801c156D);
        whos[12] = address(0x01e0C7b70E0E05a06c7cC8deeb97Fa03d6a77c9C);
        whos[13] = address(0x7Ca2296966f0054f38dfA9dd599C3aaD4b256c34);
        whos[14] = address(0x1972b3Eaf03CD4F8c4744177C656D6502dD49020);
        whos[15] = address(0x054fA0f8cdE92f9Fe429A514b7F050763178B064);
        whos[16] = address(0x46499275b5c4d67dfa46B92D89aADA3158ea392e);
        whos[17] = address(0x16edA2dD354300D39ABD1639022C2b2444b27Cef);
        whos[18] = address(0xbdac5657eDd13F47C3DD924eAa36Cf1Ec49672cc);
        whos[19] = address(0xf5f1287F7B71381fFB5Caf3b61fA0375112531BC);
        whos[20] = address(0x19BfB29CB81009dE3D7744926602cd5369151482);
        whos[21] = address(0x33382b1295f8b7b934D637AEbF54D32853Fa5d7f);
        whos[22] = address(0x782C93e1C530a283Ef738A58b5671A8fC2D8153f);
        whos[23] = address(0x08f23772549e7Eeed31cA8BF069d88F8cA2214Fa);
        whos[24] = address(0xB0B2b405c9D09d129E9F9b18c9DD218c532f2b2A);
        whos[25] = address(0x8A19Dd6b3E74cF903F3EFd0550253A9E4296efc0);
        whos[26] = address(0x8dc8De4Db3fd32178C58226D4f028a40A88d1865);
        whos[27] = address(0x19c04ca80C4168EA8aB469A0766a858D7172b320);
        amounts[0] = 45000 * 10**18;
        amounts[1] = 32000 * 10**18;
        amounts[2] = 22000 * 10**18;
        amounts[3] = 22000 * 10**18;
        amounts[4] = 10000 * 10**18;
        amounts[5] = 2000 * 10**18;
        amounts[6] = 5000 * 10**18;
        amounts[7] = 5000 * 10**18;
        amounts[8] = 2000 * 10**18;
        amounts[9] = 3500 * 10**18;
        amounts[10] = 2000 * 10**18;
        amounts[11] = 2000 * 10**18;
        amounts[12] = 4000 * 10**18;
        amounts[13] = 2000 * 10**18;
        amounts[14] = 2000 * 10**18;
        amounts[15] = 3500 * 10**18;
        amounts[16] = 2500 * 10**18;
        amounts[17] = 3500 * 10**18;
        amounts[18] = 2500 * 10**18;
        amounts[19] = 1000 * 10**18;
        amounts[20] = 1000 * 10**18;
        amounts[21] = 1000 * 10**18;
        amounts[22] = 1000 * 10**18;
        amounts[23] = 1000 * 10**18;
        amounts[24] = 1000 * 10**18;
        amounts[25] = 3500 * 10**18;
        amounts[26] = 1000 * 10**18;
        amounts[27] = 1500 * 10**18;
        tokens[0] = yyCRV;
        tokens[1] = yyCRV;
        tokens[2] = yyCRV;
        tokens[3] = yyCRV;
        tokens[4] = yyCRV;
        tokens[5] = yyCRV;
        tokens[6] = yyCRV;
        tokens[7] = yyCRV;
        tokens[8] = yyCRV;
        tokens[9] = yyCRV;
        tokens[10] = yyCRV;
        tokens[11] = yyCRV;
        tokens[12] = yyCRV;
        tokens[13] = yyCRV;
        tokens[14] = yyCRV;
        tokens[15] = yyCRV;
        tokens[16] = yyCRV;
        tokens[17] = yyCRV;
        tokens[18] = yyCRV;
        tokens[19] = yyCRV;
        tokens[20] = yyCRV;
        tokens[21] = yyCRV;
        tokens[22] = yyCRV;
        tokens[23] = yyCRV;
        tokens[24] = yyCRV;
        tokens[25] = yyCRV;
        tokens[26] = yyCRV;
        tokens[27] = yyCRV;

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Retroactive Contributor payments";

        targets[0] = address(reserves);
        signatures[0] = "oneTimeTransfers(address[],uint256[],address[])";
        calldatas[0] = abi.encode(whos, amounts, tokens);

        yamhelper.getQuorum(yamV3, me);

        roll_prop(
          targets,
          values,
          signatures,
          calldatas,
          description
        );

        /* assertTrue(false); */
    }

    function test_payout_direct() public {
        yamhelper.becomeGovernorDirect(address(reserves), me);
        address[] memory whos = new address[](28);
        uint256[] memory amounts = new uint256[](28);
        address[] memory tokens = new address[](28);
        whos[0] = address(0x4a29e88cEA7e1505DB9b6491C749Fb5d6d595265);
        whos[1] = address(0xC3edCBe0F93a6258c3933e86fFaA3bcF12F8D695);
        whos[2] = address(0x69CF70d4F6181faFd047466470Ba2119De0bCac4);
        whos[3] = address(0xA664A9cc53b9d02A9D9796Ec24C1BA958bD5aA44);
        whos[4] = address(0xDc07A76F00A16d98114097057B38Da3325A91b66);
        whos[5] = address(0xF317172D2acF09511376CE54642fC09DF0239068);
        whos[6] = address(0xEC3281124d4c2FCA8A88e3076C1E7749CfEcb7F2);
        whos[7] = address(0x3F50f328ED67860f4ef0C11552Cf4b3329dee1b5);
        whos[8] = address(0xa6D8c7A9a4567FC3E4519c4163981aC122b9f88b);
        whos[9] = address(0x7cF090168D67EA6626C590a0b708a8B7D0656dEF);
        whos[10] = address(0x9098eab0a361D29Ea5c4b5d9d1f50694ac0E9e78);
        whos[11] = address(0x83f663823484fA63A036FCe7c3cF1C09801c156D);
        whos[12] = address(0x01e0C7b70E0E05a06c7cC8deeb97Fa03d6a77c9C);
        whos[13] = address(0x7Ca2296966f0054f38dfA9dd599C3aaD4b256c34);
        whos[14] = address(0x1972b3Eaf03CD4F8c4744177C656D6502dD49020);
        whos[15] = address(0x054fA0f8cdE92f9Fe429A514b7F050763178B064);
        whos[16] = address(0x46499275b5c4d67dfa46B92D89aADA3158ea392e);
        whos[17] = address(0x16edA2dD354300D39ABD1639022C2b2444b27Cef);
        whos[18] = address(0xbdac5657eDd13F47C3DD924eAa36Cf1Ec49672cc);
        whos[19] = address(0xf5f1287F7B71381fFB5Caf3b61fA0375112531BC);
        whos[20] = address(0x19BfB29CB81009dE3D7744926602cd5369151482);
        whos[21] = address(0x33382b1295f8b7b934D637AEbF54D32853Fa5d7f);
        whos[22] = address(0x782C93e1C530a283Ef738A58b5671A8fC2D8153f);
        whos[23] = address(0x08f23772549e7Eeed31cA8BF069d88F8cA2214Fa);
        whos[24] = address(0xB0B2b405c9D09d129E9F9b18c9DD218c532f2b2A);
        whos[25] = address(0x8A19Dd6b3E74cF903F3EFd0550253A9E4296efc0);
        whos[26] = address(0x8dc8De4Db3fd32178C58226D4f028a40A88d1865);
        whos[27] = address(0x19c04ca80C4168EA8aB469A0766a858D7172b320);
        amounts[0] = 45000 * 10**18;
        amounts[1] = 32000 * 10**18;
        amounts[2] = 22000 * 10**18;
        amounts[3] = 22000 * 10**18;
        amounts[4] = 10000 * 10**18;
        amounts[5] = 2000 * 10**18;
        amounts[6] = 5000 * 10**18;
        amounts[7] = 5000 * 10**18;
        amounts[8] = 2000 * 10**18;
        amounts[9] = 3500 * 10**18;
        amounts[10] = 2000 * 10**18;
        amounts[11] = 2000 * 10**18;
        amounts[12] = 4000 * 10**18;
        amounts[13] = 2000 * 10**18;
        amounts[14] = 2000 * 10**18;
        amounts[15] = 3500 * 10**18;
        amounts[16] = 2500 * 10**18;
        amounts[17] = 3500 * 10**18;
        amounts[18] = 2500 * 10**18;
        amounts[19] = 1000 * 10**18;
        amounts[20] = 1000 * 10**18;
        amounts[21] = 1000 * 10**18;
        amounts[22] = 1000 * 10**18;
        amounts[23] = 1000 * 10**18;
        amounts[24] = 1000 * 10**18;
        amounts[25] = 3500 * 10**18;
        amounts[26] = 1000 * 10**18;
        amounts[27] = 1500 * 10**18;
        tokens[0] = yyCRV;
        tokens[1] = yyCRV;
        tokens[2] = yyCRV;
        tokens[3] = yyCRV;
        tokens[4] = yyCRV;
        tokens[5] = yyCRV;
        tokens[6] = yyCRV;
        tokens[7] = yyCRV;
        tokens[8] = yyCRV;
        tokens[9] = yyCRV;
        tokens[10] = yyCRV;
        tokens[11] = yyCRV;
        tokens[12] = yyCRV;
        tokens[13] = yyCRV;
        tokens[14] = yyCRV;
        tokens[15] = yyCRV;
        tokens[16] = yyCRV;
        tokens[17] = yyCRV;
        tokens[18] = yyCRV;
        tokens[19] = yyCRV;
        tokens[20] = yyCRV;
        tokens[21] = yyCRV;
        tokens[22] = yyCRV;
        tokens[23] = yyCRV;
        tokens[24] = yyCRV;
        tokens[25] = yyCRV;
        tokens[26] = yyCRV;
        tokens[27] = yyCRV;
        reserves.oneTimeTransfers(whos, amounts, tokens);
        assertTrue(false);
    }

}
