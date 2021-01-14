pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import { DualGovernorAlpha } from "../proposal_round_2/YAMGovernorAlphaWithLps.sol";
import { MonthlyAllowance } from "../contributor_monthly_payments/MonthlyAllowance.sol";
import { VestingPool } from "../vesting_pool/VestingPool.sol";
import { IERC20 } from "../../lib/IERC20.sol";
import { WETH9 } from "../../lib/WETH9.sol";
import { Timelock } from "../../governance/TimeLock.sol";
import { CitadelLending } from "./Citadel.sol";


contract CitadelUser {
    function doDeposit(YAMHelper yamhelper, CitadelLending pool, uint8 marketIndex, uint256 amount) public {
        CitadelLending.Market memory market = pool.getMarketInfo(marketIndex);
        yamhelper.write_map(market.token, "balanceOf(address)", address(this), amount);
        IERC20(market.token).approve(address(pool), uint256(-1));
        pool.deposit(marketIndex, amount);
    }
}

contract CitadelTesting is YAMv3Test {
    function () external payable {}

    event E(bytes8);
    event E2(bytes);
    event S(string);
    event Coefs(uint128[] coefs);

    CitadelLending pool;
    CitadelUser user;
    function setUp() public {
        setUpCore();
        pool = new CitadelLending();
        user = new CitadelUser();
    }

    function setup_pool() public {
        address[] memory tokens = new address[](4);
        tokens[0] = WETH;
        tokens[1] = yyCRV;
        tokens[2] = DAI;
        tokens[3] = DPI;

        // usdc denominated
        address denominatingToken = USDC;

        // oracle_paths
        address[][] memory oracle_paths = new address[][](4);
        oracle_paths[0] = new address[](1);
        oracle_paths[0][0] = pairFor(WETH, denominatingToken);
        oracle_paths[1] = new address[](2);
        oracle_paths[1][0] = pairFor(yyCRV, WETH);
        oracle_paths[1][1] = pairFor(WETH, denominatingToken);
        oracle_paths[2] = new address[](2);
        oracle_paths[2][0] = pairFor(DAI, WETH);
        oracle_paths[2][1] = pairFor(WETH, denominatingToken);
        oracle_paths[3] = new address[](2);
        oracle_paths[3][0] = pairFor(DPI, WETH);
        oracle_paths[3][1] = pairFor(WETH, denominatingToken);

        // rate coefs
        bytes memory e = abi.encodePacked( uint8(0), uint8(0), uint8(10), uint8(0), uint8(50), uint8(10), uint8(20), uint8(10));
        bytes8 coefs_b = bytesToBytes8(e);
        uint64 coefs = uint64(coefs_b);
        uint64[] memory coefficients = new uint64[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            coefficients[i] = coefs;
        }

        uint256[] memory marginPremiums = new uint256[](tokens.length);
        /* marginPremiums[0] = 10**18; */
        /* marginPremiums[1] = 10**18; */
        /* marginPremiums[2] = 10**18; */
        /* marginPremiums[3] = 10**18; */


        uint128 insuranceRate = 75*10**16;
        uint128 earningsRate = 85*10**16;
        uint128 marginRatio = 15*10**16;
        uint32 period = 60*60;
        pool.initialize(
          tokens,
          denominatingToken,
          oracle_paths,
          coefficients,
          marginPremiums,
          insuranceRate,
          earningsRate,
          marginRatio,
          period
        );
        yamhelper.ff(60*60);
    }

    function test_citadel_setup() public {
        assertTrue(false);
        //tokens
        setup_pool();

        yamhelper.ff(60*60);
        pool.refresh_price(0);
        pool.getMarketPrice(0);
        pool.refresh_price(1);
        pool.getMarketPrice(1);
        pool.refresh_price(2);
        pool.getMarketPrice(2);
        pool.refresh_price(3);
        pool.getMarketPrice(3);
    }

    function test_citadel_deposit() public {
        setup_pool();
        yamhelper.write_map(WETH, "balanceOf(address)", address(this), 300*10**18);
        IERC20(WETH).approve(address(pool), uint256(-1));
        pool.deposit(0, 10*10**18);
        assertEq(IERC20(WETH).balanceOf(address(pool)), 10*10**18);
    }

    function test_citadel_withdraw() public {
        setup_pool();
        yamhelper.write_map(WETH, "balanceOf(address)", address(this), 300*10**18);
        IERC20(WETH).approve(address(pool), uint256(-1));
        pool.deposit(0, 10*10**18);
        assertEq(IERC20(WETH).balanceOf(address(pool)), 10*10**18);
        pool.withdraw(0, 10*10**18);
        assertEq(IERC20(WETH).balanceOf(address(pool)), 0);
        assertEq(IERC20(WETH).balanceOf(address(this)), 300*10**18);
    }

    function test_citadel_borrow() public {
        setup_pool();
        yamhelper.write_map(WETH, "balanceOf(address)", address(this), 300*10**18);
        IERC20(WETH).approve(address(pool), uint256(-1));
        pool.deposit(0, 10*10**18);
        user.doDeposit(yamhelper, pool, 1, 100*10**18);
        pool.withdraw(1, 10**18);
        pool.withdraw(1, 10**18);

        assertEq(IERC20(yyCRV).balanceOf(address(this)), 10**18);
        assertEq(IERC20(yyCRV).balanceOf(address(pool)), 0);
        assertEq(IERC20(WETH).balanceOf(address(pool)), 10*10**18);
    }

    function test_citadel_flashloan() public {
        setup_pool();
        yamhelper.write_map(WETH, "balanceOf(address)", address(this), 300*10**18);
        IERC20(WETH).approve(address(pool), uint256(-1));
        IERC20(yyCRV).approve(address(pool), uint256(-1));

        user.doDeposit(yamhelper, pool, 1, 10**18);

        CitadelLending.AnyArg[] memory args = new CitadelLending.AnyArg[](3);
        args[0] = CitadelLending.AnyArg({
            // what operation?
            op: CitadelLending.Op.Withdraw,
            // market index
            marketIndex: 1,
            // secondary market index for liquidation & vaporize
            secondaryMarketIndex: 0,
            // index of the address list to reference
            fromIndex: 0,
            // index of the address list to reference
            toIndex: 0,
            // For anything needing an amount
            amount: 10**18,
            // For calls/flashloans
            externalAddress: address(this),
            data: ""
        });

        args[1] = CitadelLending.AnyArg({
            // what operation?
            op: CitadelLending.Op.Call,
            // market index
            marketIndex: 0,
            // secondary market index for liquidation & vaporize
            secondaryMarketIndex: 0,
            // index of the address list to reference
            fromIndex: 0,
            // index of the address list to reference
            toIndex: 0,
            // For anything needing an amount
            amount: 0,
            // For calls/flashloans
            externalAddress: address(this),
            data: ""
        });

        args[2] = CitadelLending.AnyArg({
            // what operation?
            op: CitadelLending.Op.Deposit,
            // market index
            marketIndex: 1,
            // secondary market index for liquidation & vaporize
            secondaryMarketIndex: 0,
            // index of the address list to reference
            fromIndex: 0,
            // index of the address list to reference
            toIndex: 0,
            // For anything needing an amount
            amount: 10**18,
            // For calls/flashloans
            externalAddress: address(this),
            data: ""
        });

        address[] memory whos = new address[](1);
        whos[0] = address(this);

        pool.operate(whos, args);

        /* assertEq(IERC20(yyCRV).balanceOf(address(this)), 10**18);
        assertEq(IERC20(yyCRV).balanceOf(address(pool)), 0);
        assertEq(IERC20(WETH).balanceOf(address(pool)), 10*10**18); */
    }

    function test_citadel_trade() public {
        setup_pool();
        yamhelper.write_map(WETH, "balanceOf(address)", address(this), 300*10**18);
        IERC20(WETH).approve(address(pool), uint256(-1));
        IERC20(yyCRV).approve(address(pool), uint256(-1));

        user.doDeposit(yamhelper, pool, 1, 10**18);

        CitadelLending.AnyArg[] memory args = new CitadelLending.AnyArg[](3);
        args[0] = CitadelLending.AnyArg({
            // what operation?
            op: CitadelLending.Op.Withdraw,
            // market index
            marketIndex: 1,
            // secondary market index for liquidation & vaporize
            secondaryMarketIndex: 0,
            // index of the address list to reference
            fromIndex: 0,
            // index of the address list to reference
            toIndex: 0,
            // For anything needing an amount
            amount: 10**18,
            // For calls/flashloans
            externalAddress: address(this),
            data: ""
        });

        args[1] = CitadelLending.AnyArg({
            // what operation?
            op: CitadelLending.Op.Call,
            // market index
            marketIndex: 0,
            // secondary market index for liquidation & vaporize
            secondaryMarketIndex: 0,
            // index of the address list to reference
            fromIndex: 0,
            // index of the address list to reference
            toIndex: 0,
            // For anything needing an amount
            amount: 0,
            // For calls/flashloans
            externalAddress: address(this),
            data: ""
        });

        args[2] = CitadelLending.AnyArg({
            // what operation?
            op: CitadelLending.Op.Deposit,
            // market index
            marketIndex: 0,
            // secondary market index for liquidation & vaporize
            secondaryMarketIndex: 0,
            // index of the address list to reference
            fromIndex: 0,
            // index of the address list to reference
            toIndex: 0,
            // For anything needing an amount
            amount: 10**18,
            // For calls/flashloans
            externalAddress: address(this),
            data: ""
        });

        address[] memory whos = new address[](1);
        whos[0] = address(this);

        pool.operate(whos, args);

        /* assertEq(IERC20(yyCRV).balanceOf(address(this)), 10**18);
        assertEq(IERC20(yyCRV).balanceOf(address(pool)), 0);
        assertEq(IERC20(WETH).balanceOf(address(pool)), 10*10**18); */
    }

    function citadelCall(address sender, bytes memory data) public {
        emit S("was citadelCall");
    }


    function bytesToBytes8(bytes memory b) public pure returns (bytes8) {
        bytes8 out;

        for (uint i = 0; i < 8; i++) {
            out |= bytes8(b[i] & 0xFF) >> (i * 8);
        }
        return out;
    }
}
