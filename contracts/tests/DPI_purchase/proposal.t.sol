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

    Trader grapefruit;

    function setUp() public {
        setUpCore();
        grapefruit = new Trader();
        otc = new OTC();
        r2 = new YAMReserves2(
            address(yyCRV),
            address(yamV3)
        );
        yamhelper.write_flat(address(reserves), "gov()", me);
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

        r2.whitelist_withdrawals(
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

        r2.whitelist_withdrawals(
            whos,
            amounts,
            token
        );
    }
}
