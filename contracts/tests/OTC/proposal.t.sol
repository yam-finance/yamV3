// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import { YAMReserves2 } from "./YAMReserves2.sol";
import { OTC } from "./OTC.sol";


contract Trader {
    function doTrade(OTC otc, uint256 trader_sell_amount, address trader_seller_token, uint256 expected_amount) public {
        IERC20(trader_seller_token).approve(address(otc), trader_sell_amount);
        otc.trade(trader_sell_amount, expected_amount);
    }
}

contract OTCProp is YAMv3Test {

    OTC otc;
    YAMReserves2 r2;

    address DPI = address(0x1494CA1F11D487c2bBe4543E90080AeBa4BA3C2b);
    address USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    OTC otc_onchain = OTC(0x92ab5CCe7Af1605da2681458aE52a0BEc4eCB74C);
    YAMReserves2 r2_onchain = YAMReserves2(0x97990B693835da58A281636296D2Bf02787DEa17);
    Trader grapefruit;

    function setUp() public {
        setUpCore();
        grapefruit = new Trader();
        otc = new OTC();
        r2 = new YAMReserves2(
            address(yyCRV),
            address(yamV3)
        );
        /* yamhelper.write_flat(address(reserves), "gov()", me); */
    }

    function test_bounds_and_consult() public {
      otc_onchain.consult();
      otc_onchain.bounds();
    }

    function test_otc_prop() public {
      yamhelper.getQuorum(yamV3, me);

      GovernorAlpha gov = GovernorAlpha(timelock.admin());
      uint256 id = gov.latestProposalIds(me);

      vote_pos_latest();

      hevm.roll(block.number +  12345);

      GovernorAlpha.ProposalState state = gov.state(id);
      assertTrue(state == GovernorAlpha.ProposalState.Succeeded);

      gov.queue(id);

      hevm.warp(now + timelock.delay());

      gov.execute(id);
      assertTrue(false);
    }

    function test_live() public {
        assertTrue(false); // force verbose
        address[] memory targets = new address[](6);
        uint256[] memory values = new uint256[](6);
        string[] memory signatures = new string[](6);
        bytes[] memory calldatas = new bytes[](6);
        string memory description = "Accept governances, upgrade reserves, DPI otc purchase";

        /// ---- ACCEPT GOVS ---- \\\
        // -- accept gov otc
        targets[0] = address(otc_onchain);
        signatures[0] = "acceptGov()";

        // -- accept gov reserves
        targets[1] = address(r2_onchain);
        signatures[1] = "_acceptGov()";


        /// ---- UPGRADE RESERVES ---- \\\
        // -- migrate reserves
        targets[2] = address(reserves);
        signatures[2] = "migrateReserves(address,address[])";
        address[] memory tokens = new address[](1);
        tokens[0] = yyCRV;
        calldatas[2] = abi.encode(address(r2_onchain), tokens);

        // -- update reserves in rebaser
        targets[3] = address(rebaser);
        signatures[3] = "setReserveContract(address)";
        calldatas[3] = abi.encode(address(r2_onchain));


        /// ---- SETUP OTC ---- \\\
        targets[4] = address(r2_onchain);
        signatures[4] = "whitelistWithdrawals(address[],uint256[],address[])";
        address[] memory whos = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory token = new address[](1);
        whos[0] = address(otc_onchain);
        amounts[0] = 215518*10**18;
        token[0] = address(yyCRV);
        calldatas[4] = abi.encode(whos, amounts, token);

        targets[5] = address(otc_onchain);
        signatures[5] = "setup_sale(address,address,address,uint256,uint256,uint256,address,address,address)";
        calldatas[5] = abi.encode(
          address(0x97a7E840D05Ec436A2d7FE3b5408f89467174dE6), // trader
          address(yyCRV), // sell_token,
          address(DPI), // purchase_token,
          uint256(amounts[0]), // sell_amount_,
          uint256(2 * 60 * 60), // twap_period,
          uint256(5 * 10**16), // twap_bounds_,
          address(0x9346C20186D1794101B8517177A1b15c49c9ff9b), // uniswap1,
          address(0x4d5ef58aAc27d99935E5b6B4A6778ff292059991), // uniswap2, // if two hop
          address(r2_onchain) // reserve_
        );

        yamhelper.getQuorum(yamV3, me);

        roll_prop(
          targets,
          values,
          signatures,
          calldatas,
          description
        );

        yamhelper.ff(60*60*2);

        otc_onchain.update_twap();

        otc_onchain.bounds();
        otc_onchain.quote(3200*10**18, amounts[0]);

        /* yamhelper.write_map(DPI, "balanceOf(address)", address(grapefruit), 3200*10**18); */

        /* grapefruit.doTrade(otc, 3200*10**18, DPI, saleAmount); */
      }

    //
    // TESTS
    //
    function test_double_hop_purchase() public {
        setup_reserves_purchase();

        uint256 purchaseAmount = 3200*10**18;

        otc.setup_purchase(
            address(grapefruit),
            yyCRV,
            DPI,
            purchaseAmount,
            2 * 60 * 60, // 2 hours
            10**16, // 1%
            pairFor(yyCRV, WETH),
            pairFor(WETH, DPI), // if two hop
            address(r2)
        );

        yamhelper.ff(60*60*2);

        otc.update_twap();

        otc.bounds();
        otc.quote(purchaseAmount, 200000 * 10**18);

        yamhelper.write_map(DPI, "balanceOf(address)", address(grapefruit), 3200*10**18);

        otc.purchase_amount();

        grapefruit.doTrade(otc, purchaseAmount, DPI, 200000 * 10**18);

    }

    function test_double_hop() public {
        setup_reserves();

        uint256 saleAmount = 215518*10**18;

        otc.setup_sale(
            address(grapefruit),
            yyCRV,
            DPI,
            saleAmount,
            2 * 60 * 60, // 2 hours
            10**16, // 1%
            pairFor(yyCRV, WETH),
            pairFor(WETH, DPI), // if two hop
            address(r2)
        );

        yamhelper.ff(60*60*2);

        otc.update_twap();

        otc.bounds();
        otc.quote(3200*10**18, saleAmount);

        yamhelper.write_map(DPI, "balanceOf(address)", address(grapefruit), 3200*10**18);

        grapefruit.doTrade(otc, 3200*10**18, DPI, saleAmount);

    }

    function testFail_double_hop() public {
        setup_reserves();

        uint256 saleAmount = 215518*10**18;

        otc.setup_sale(
            address(grapefruit),
            yyCRV,
            DPI,
            saleAmount,
            2 * 60 * 60, // 2 hours
            10**16, // 1%
            pairFor(yyCRV, WETH),
            pairFor(WETH, DPI), // if two hop
            address(r2)
        );

        yamhelper.ff(60*60*2);

        otc.update_twap();

        otc.bounds();
        otc.quote(1200*10**18, saleAmount);

        yamhelper.write_map(DPI, "balanceOf(address)", address(grapefruit), 1200*10**18);

        grapefruit.doTrade(otc, 1200*10**18, DPI, saleAmount);

    }

    function test_double_hop_twice() public {
        setup_reserves();

        uint256 saleAmount = 215518*10**18;

        uint256 purchaseAmount = 3400 * 10**18;

        otc.setup_sale(
            address(grapefruit),
            yyCRV,
            DPI,
            saleAmount,
            2 * 60 * 60, // 2 hours
            10**16, // 1%
            pairFor(yyCRV, WETH),
            pairFor(WETH, DPI), // if two hop
            address(r2)
        );

        yamhelper.ff(60*60*2);

        otc.update_twap();

        otc.bounds();
        otc.quote(purchaseAmount, saleAmount);

        yamhelper.write_map(DPI, "balanceOf(address)", address(grapefruit), purchaseAmount);

        grapefruit.doTrade(otc, purchaseAmount, DPI, saleAmount);

        address[] memory whos = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory token = new address[](1);
        whos[0] = address(otc);
        amounts[0] = 215518*10**18;
        token[0] = address(yyCRV);

        r2.whitelistWithdrawals(
            whos,
            amounts,
            token
        );

        otc.setup_sale(
            address(grapefruit),
            yyCRV,
            DPI,
            saleAmount,
            2 * 60 * 60, // 2 hours
            10**16, // 1%
            pairFor(yyCRV, WETH),
            pairFor(WETH, DPI), // if two hop
            address(r2)
        );

        yamhelper.ff(60*60*2);

        otc.update_twap();

        otc.bounds();
        otc.quote(purchaseAmount, saleAmount);

        yamhelper.write_map(DPI, "balanceOf(address)", address(grapefruit), purchaseAmount);

        grapefruit.doTrade(otc, purchaseAmount, DPI, saleAmount);

    }

    function test_single_hop() public {
        setup_reserves();

        uint256 saleAmount = 215518*10**18;
        otc.setup_sale(
            address(grapefruit),
            yyCRV,
            WETH,
            saleAmount,
            2 * 60 * 60, // 2 hours
            10**16, // 1%
            pairFor(yyCRV, WETH),
            address(0), // if two hop
            address(r2)
        );
        yamhelper.ff(60*60*2);

        otc.update_twap();


        uint256 price = otc.consult();

        uint256 purchaseAmount = 215518*10**18 * price / 10**18;

        otc.bounds();
        otc.quote(purchaseAmount, saleAmount);

        yamhelper.write_map(WETH, "balanceOf(address)", address(grapefruit), purchaseAmount);

        grapefruit.doTrade(otc, purchaseAmount, WETH, saleAmount);
    }

    function test_single_hop_dif_decs() public {
        setup_reserves();

        uint256 saleAmount = 215518*10**18;
        otc.setup_sale(
            address(grapefruit),
            yyCRV,
            USDC,
            saleAmount,
            2 * 60 * 60, // 2 hours
            10**16, // 1%
            pairFor(yyCRV, USDC),
            address(0), // if two hop
            address(r2)
        );
        yamhelper.ff(60*60*2);

        otc.update_twap();

        uint256 price = otc.consult();

        uint256 purchaseAmount = 215518 * price;

        otc.bounds();
        otc.quote(purchaseAmount, saleAmount);

        yamhelper.write_map(USDC, "balanceOf(address)", address(grapefruit), purchaseAmount);

        grapefruit.doTrade(otc, purchaseAmount, USDC, saleAmount);
    }

    function test_double_hop_dif_dec() public {
        setup_reserves();


        uint256 purchaseAmount = 215518 * 116 * 10**4;
        uint256 saleAmount = 215518*10**18;
        otc.setup_sale(
            address(grapefruit),
            yyCRV,
            USDC,
            saleAmount,
            2 * 60 * 60, // 2 hours
            10**16, // 1%
            pairFor(yyCRV, WETH),
            pairFor(WETH, USDC), // if two hop
            address(r2)
        );
        yamhelper.ff(60*60*2);

        otc.update_twap();

        otc.bounds();
        otc.quote(purchaseAmount, saleAmount);

        yamhelper.write_balanceOf(USDC, address(grapefruit), purchaseAmount);

        grapefruit.doTrade(otc, purchaseAmount, USDC, saleAmount);
    }

    function test_double_hop_dif_dec_top() public {
        setup_reserves();


        uint256 saleAmount = 215518 * 116 * 10**4;
        uint256 purchaseAmount = 215518*10**18;
        otc.setup_sale(
            address(grapefruit),
            USDC,
            yyCRV,
            saleAmount,
            2 * 60 * 60, // 2 hours
            10**16, // 1%
            pairFor(USDC, WETH),
            pairFor(WETH, yyCRV), // if two hop
            address(r2)
        );

        yamhelper.write_balanceOf(USDC, address(r2), 215518 * 116 * 10**4);

        yamhelper.ff(60*60*2);

        otc.update_twap();

        otc.bounds();
        otc.quote(purchaseAmount, saleAmount);

        yamhelper.write_balanceOf(yyCRV, address(grapefruit), 215518 * 10**18);

        grapefruit.doTrade(otc, 215518*10**18, USDC, 215518 * 116 * 10**4);
    }

    function setup_reserves() public {
        require(reserves.gov() == me, "not gov");
        address[] memory tokens = new address[](1);
        tokens[0] = yyCRV;
        reserves.migrateReserves(
            address(r2),
            tokens
        );

        address[] memory whos = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory token = new address[](1);
        whos[0] = address(otc);
        amounts[0] = 215518*10**18;
        token[0] = address(yyCRV);

        r2.whitelistWithdrawals(
            whos,
            amounts,
            token
        );
    }

    function setup_reserves_purchase() public {
        require(reserves.gov() == me, "not gov");
        address[] memory tokens = new address[](1);
        tokens[0] = yyCRV;
        reserves.migrateReserves(
            address(r2),
            tokens
        );

        address[] memory whos = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory token = new address[](1);
        whos[0] = address(otc);
        amounts[0] = 250000*10**18;
        token[0] = address(yyCRV);

        r2.whitelistWithdrawals(
            whos,
            amounts,
            token
        );
    }
}
