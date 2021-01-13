// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import {IERC20} from "../../lib/IERC20.sol";
import {UMAFarmingFeb} from "../uma_farming/UMAFarmingFeb.sol";
import {SynthMinter} from "../uma_farming/UMAFarmingFeb.sol";

// Prop for December contributor payment and stream setup
contract Prop7 is YAMv3Test {
    UMAFarmingFeb umaFarming;

    IERC20 internal constant FEB_UGAS = IERC20(
        0x81fAb276aEC924fBDe190cf379783526D413CF70
    );

    SynthMinter internal constant MINTER = SynthMinter(
        0xEAA081a9fad4607CdF046fEA7D4BF3DfEf533282
    );

    function setUp() public {
        setUpCore();
        umaFarming = new UMAFarmingFeb(address(timelock));
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
     * 1. Accept gov of UMA Farming contract
     * 2. Approve WETH for UMA Farming
     * 3. Setup enter action for UMA Farming
     **/
    function test_onchain_prop_7() public {
        assertTrue(false);

        uint256 reservesPreWETHBalance = weth.balanceOf(address(reserves));
        roll_enter_prop();
        umaFarming.update_twap();

        yamhelper.ff(61 minutes);

        umaFarming.enter();
        uint256 reservesPostWETHBalance = weth.balanceOf(address(reserves));
        assertTrue(reservesPostWETHBalance < reservesPreWETHBalance / 50);
    }

    function test_enter_and_exit() public {
        //ENTER
        uint256 reservesPreWETHBalance = weth.balanceOf(address(reserves));
        roll_enter_prop();
        umaFarming.update_twap();
        yamhelper.ff(61 minutes);
        umaFarming.enter();

        roll_exit_prop();
        umaFarming.update_twap();

        yamhelper.ff(61 minutes);

        umaFarming.exit();
        uint256 reservesPostWETHBalance = weth.balanceOf(address(reserves));
        assertEq(reservesPostWETHBalance, reservesPreWETHBalance); // This should fail, the exact amount will change
        uint256 reservesPostUGASBalance = FEB_UGAS.balanceOf(address(reserves));
        assertEq(reservesPostUGASBalance, 0); // This should fail, the exact amount will change
    }

    function test_twap_bounds() public {
        roll_enter_prop();
        umaFarming.update_twap();
        yamhelper.ff(61 minutes);
        address[] memory path = new address[](2);
        path[0] = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        path[1] = address(0x81fAb276aEC924fBDe190cf379783526D413CF70);
        uniRouter.swapExactETHForTokens.value(10000000000000000000)(
            1,
            path,
            address(this),
            block.timestamp + 1
        );
        expect_revert_with(address(umaFarming), "enter()", "", "Market rate is outside bounds");
    }

    /**
     * This test does a purchase of uGAS on the Uniswap pool between enter and exit. That means there isn't enough uGAS to pay all debt
     * This will happen if the uGAS price increases between enter and exit. The debt can either be paid by someone else (sent to the farming contract and redeem called)
     * The collateral will also be claimable after expiry, which is tested below
     */
    function test_exit_with_ugas_purchase() public {
        //ENTER
        uint256 reservesPreWETHBalance = weth.balanceOf(address(reserves));
        roll_enter_prop();
        umaFarming.update_twap();
        yamhelper.ff(61 minutes);
        umaFarming.enter();
        address[] memory path = new address[](2);
        path[0] = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        path[1] = address(0x81fAb276aEC924fBDe190cf379783526D413CF70);
        uniRouter.swapExactETHForTokens.value(50000000000000000000)(
            1,
            path,
            address(this),
            block.timestamp + 1
        );
        roll_exit_prop();
        umaFarming.update_twap();

        yamhelper.ff(61 minutes);

        umaFarming.exit();
        uint256 reservesPostWETHBalance = weth.balanceOf(address(reserves));
        assertEq(reservesPostWETHBalance, reservesPreWETHBalance); // This should fail, the exact amount will change, but should be significantly less than originally
        uint256 reservesPostUGASBalance = FEB_UGAS.balanceOf(address(reserves));
        assertEq(reservesPostUGASBalance, 0);

        yamhelper.ff(60 days);

        MINTER.expire();
        roll_settle_expired_prop();
        reservesPostWETHBalance = weth.balanceOf(address(reserves));
        assertEq(reservesPostWETHBalance, reservesPreWETHBalance); // This should be very close
    }

    function roll_exit_prop() internal {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);

        string memory description = "Approve exiting UGAS farming";

        // -- Approve exit for umaFarming
        targets[0] = address(umaFarming);
        signatures[0] = "_approveExit()";
        calldatas[0] = "";

        emit TEST(targets, values, signatures, calldatas, description);
        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description);
    }

    function roll_enter_prop() internal {
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        string[] memory signatures = new string[](3);
        bytes[] memory calldatas = new bytes[](3);

        string memory description = "Setup uGAS Feb minting/lping";

        // -- Accept governance of umaFarming contract
        targets[0] = address(umaFarming);
        signatures[0] = "_acceptGov()";
        calldatas[0] = "";

        // -- Approve WETH for UMA Farming
        targets[1] = address(reserves);
        signatures[1] = "whitelistWithdrawals(address[],uint256[],address[])";
        address[] memory whos = new address[](1);
        whos[0] = address(umaFarming);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = uint256(-1);
        address[] memory tokens = new address[](1);
        tokens[0] = address(WETH);
        calldatas[1] = abi.encode(whos, amounts, tokens);

        // -- Approve enter for umaFarming
        targets[2] = address(umaFarming);
        signatures[2] = "_approveEnter()";
        calldatas[2] = "";

        emit TEST(targets, values, signatures, calldatas, description);
        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description);
    }

    function roll_settle_expired_prop() internal {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        string[] memory signatures = new string[](2);
        bytes[] memory calldatas = new bytes[](2);


            string memory description
         = "Call _settleExpired on farming contract, retrieve WETH";

        // -- Approve exit for umaFarming
        targets[0] = address(umaFarming);
        signatures[0] = "_settleExpired()";
        calldatas[0] = "";

        // -- Approve exit for umaFarming
        targets[1] = address(umaFarming);
        signatures[1] = "_getTokenFromHere(address)";
        calldatas[1] = abi.encode(address(weth));

        emit TEST(targets, values, signatures, calldatas, description);
        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description); // This will actually fail due to the price not being set yet
    }
}
