pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import { YamGovernorAlpha } from "../../governance/YamGovernorAlpha.sol";
import { MonthlyAllowance } from "../contributor_monthly_payments/MonthlyAllowance.sol";
import { VestingPool } from "../vesting_pool/VestingPool.sol";
import { IERC20 } from "../../lib/IERC20.sol";
import { WETH9 } from "../../lib/WETH9.sol";
import { Timelock } from "../../governance/TimeLock.sol";
import { UmbrellaMetaPool } from "./UmbrellaMetaPool.sol";
import { UmbrellaMetaPoolFactory } from "./UmbrellaMetaPoolFactory.sol";


contract CoverageUser {
    address public constant DAI = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    function doBuy(UmbrellaMetaPool pool, uint128 amount) external {
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.buyProtection(
            0, // dydx
            amount, // 1 pay token
            86400*14, // 1 week
            5*amount,
            block.timestamp
        );
    }
    function doDetailedBuy(UmbrellaMetaPool pool, uint8 index, uint128 amount, uint256 duration, uint256 maxPay, uint256 deadline) external {
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.buyProtection(
            index, // dydx
            amount, // 1 pay token
            uint128(duration), // 1 week
            uint128(maxPay),
            deadline
        );
    }

    function doCover(UmbrellaMetaPool pool, uint128 amount) external {
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.provideCoverage(
            amount
        );
    }

    function doClaim(UmbrellaMetaPool pool, uint256 pid) external {
        pool.claim(pid);
    }

    function doClaimPremiums(UmbrellaMetaPool pool) external {
        pool.claimPremiums();
    }
}

contract Prop3 is YAMv3Test {
    function () external payable {}

    event E(bytes8);
    event E2(bytes);
    event Coefs(uint128[] coefs);

    address umbrellaMetaPoolTemplate;
    UmbrellaMetaPoolFactory factory;
    CoverageUser cov_user;
    UmbrellaMetaPool pool;

    function setUp() public {
        setUpCore();
        umbrellaMetaPoolTemplate = address(new UmbrellaMetaPool());
        factory = new UmbrellaMetaPoolFactory(umbrellaMetaPoolTemplate);
        cov_user = new CoverageUser();
    }

    function initialize_pool() public {
        /* assertTrue(false); */
        bytes memory e = abi.encodePacked( uint8(0), uint8(0), uint8(10), uint8(0), uint8(50), uint8(10), uint8(20), uint8(10));
        emit E2(e);
        bytes8 coefs_b = bytesToBytes8(e);
        emit E(coefs_b);
        uint64 coefs = uint64(coefs_b);
        /* uint64 coefs = uint64(uint256(helper.bytesToBytes32(as_bytes, 0))); */

        uint128 creatorFee_ = 1*10**16;
        uint128 arbiterFee_ = 2*10**16;
        uint128 rollover_   = 5*10**16;
        string[] memory concepts = new string[](3);
        concepts[0] = "dydx";
        concepts[1] = "aave";
        concepts[2] = "compound";
        string memory description = "This pool covers dydx (solo margin), aave, and compound lending platforms. If a bug or hack occurs resulting in a loss of funds. If it is contested, the arbiter will default to payout";

        UmbrellaMetaPool.Fees memory fees = UmbrellaMetaPool.Fees({
          creatorFee: creatorFee_,
          arbiterFee: arbiterFee_,
          rollover: rollover_
        });
        pool = factory.createPool(
            UmbrellaMetaPool.Parameters(DAI,
            coefs,
            86400*365+1,
            fees,
            1*10**15,
            7*86400,
            2*7*86400,
            concepts,
            description,
            me,
            me
        ));
        uint128[] memory coefs2 = pool.getCoefficients();
        assertEq(uint256(coefs2[0]), 10, "c_0");
        assertEq(uint256(coefs2[1]), 20, "c_1");
        assertEq(uint256(coefs2[2]), 10, "c_2");
        assertEq(uint256(coefs2[3]), 50, "c_3");
        assertEq(uint256(coefs2[4]), 0, "c_4");
        assertEq(uint256(coefs2[5]), 10, "c_5");
        emit Coefs(coefs2);
        UmbrellaMetaPool.CreatorInfo memory creatorInfo = pool.getCreatorInfo();
        assertEq(uint256(creatorInfo.creatorFeePerc), uint256(creatorFee_), "Creator Fee");
        UmbrellaMetaPool.ArbiterInfo memory arbiterInfo = pool.getArbiterInfo();
        assertEq(uint256(arbiterInfo.arbiterFeePerc), uint256(arbiterFee_), "Arbiter Fee");
        assertEq(uint256(pool.rollover()), uint256(rollover_), "rollover");
        assertEq(creatorInfo.creatorAddr, me, "creator");
        assertEq(arbiterInfo.arbiterAddr, me, "arbiter");
        assertTrue(pool.arbSet());
    }

    function initialize_eth_pool() public {
        /* assertTrue(false); */
        bytes memory e = abi.encodePacked( uint8(0), uint8(0), uint8(10), uint8(0), uint8(50), uint8(10), uint8(20), uint8(10));
        emit E2(e);
        bytes8 coefs_b = bytesToBytes8(e);
        emit E(coefs_b);
        uint64 coefs = uint64(coefs_b);
        /* uint64 coefs = uint64(uint256(helper.bytesToBytes32(as_bytes, 0))); */

        uint128 creatorFee_ = 1*10**16;
        uint128 arbiterFee_ = 2*10**16;
        uint128 rollover_   = 5*10**16;
        string[] memory concepts = new string[](3);
        concepts[0] = "dydx";
        concepts[1] = "aave";
        concepts[2] = "compound";
        string memory description = "This pool covers dydx (solo margin), aave, and compound lending platforms. If a bug or hack occurs resulting in a loss of funds. If it is contested, the arbiter will default to payout";

        UmbrellaMetaPool.Fees memory fees = UmbrellaMetaPool.Fees({
          creatorFee: creatorFee_,
          arbiterFee: arbiterFee_,
          rollover: rollover_
        });
        pool = factory.createPool(
          UmbrellaMetaPool.Parameters(
            WETH,
            coefs,
            86400*365+1,
            fees,
            1*10**10,
            7*60*60*24, // 1 week
            2*7*60*60*24, // 2 weeks
            concepts,
            description,
            me,
            me
        ));
        uint128[] memory coefs2 = pool.getCoefficients();
        assertEq(uint256(coefs2[0]), 10, "c_0");
        assertEq(uint256(coefs2[1]), 20, "c_1");
        assertEq(uint256(coefs2[2]), 10, "c_2");
        assertEq(uint256(coefs2[3]), 50, "c_3");
        assertEq(uint256(coefs2[4]), 0, "c_4");
        assertEq(uint256(coefs2[5]), 10, "c_5");
        emit Coefs(coefs2);
        UmbrellaMetaPool.CreatorInfo memory creatorInfo = pool.getCreatorInfo();
        assertEq(uint256(creatorInfo.creatorFeePerc), uint256(creatorFee_), "Creator Fee");
        UmbrellaMetaPool.ArbiterInfo memory arbiterInfo = pool.getArbiterInfo();
        assertEq(uint256(arbiterInfo.arbiterFeePerc), uint256(arbiterFee_), "Arbiter Fee");
        assertEq(uint256(pool.rollover()), uint256(rollover_), "rollover");
        assertEq(creatorInfo.creatorAddr, me, "creator");
        assertEq(arbiterInfo.arbiterAddr, me, "arbiter");
        assertTrue(pool.arbSet());
    }

    function test_ycp_pool_init() public {
        initialize_pool();
    }

    function test_ycp_provide() public {
        initialize_pool();
        yamhelper.write_balanceOf(DAI, me, 100*10**18);
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.provideCoverage(100*10**18);
        assertEq(uint256(pool.reserves()), 100*10**18, "reserves");
    }

    function test_ycp_pricing() public {
        initialize_pool();
        yamhelper.write_balanceOf(DAI, me, 100*10**18);
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.provideCoverage(100*10**18);
        uint256 rate = pool.getInterestRate(50*10**18, 100*10**18);
        assertEq(rate, 8125682581, "rate");
        uint256 price = pool.price(50*10**18, 86400*365, 0, 100*10**18);
        assertEq(price, 12812576293720800000, "price");
    }

    function test_ycp_buy_storage() public {
        initialize_pool();
        yamhelper.write_balanceOf(DAI, me, 100*10**18);
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.provideCoverage(100*10**18);

        yamhelper.write_balanceOf(DAI, address(cov_user), 10*10**18);

        assertEq(uint256(pool.reserves()), 100*10**18, "reserves");
        assertEq(uint256(pool.utilized()), 0, "utilized");

        cov_user.doBuy(pool, 10**18);
        UmbrellaMetaPool.Protection memory pro = pool.getProtectionInfo(0);

        assertEq(uint(pro.coverageAmount), 10**18,                     "coverage amount");
        assertEq(          uint(pro.paid), 3912712519564800,           "coverage payment");
        assertEq(              pro.holder, address(cov_user),          "coverage holder");
        assertEq(         uint(pro.start), block.timestamp,            "coverage start");
        assertEq(        uint(pro.expiry), block.timestamp + 86400*14, "coverage expiry");
        assertEq(  uint(pro.conceptIndex), 0,                          "coverage concept Index");
        assertTrue(pro.status == UmbrellaMetaPool.Status.Active);

        assertEq(pool.utilized(), uint(pro.coverageAmount), "pool utilized");
    }

    function test_ycp_sweep() public {
        initialize_pool();
        yamhelper.write_balanceOf(DAI, me, 100*10**18);
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.provideCoverage(100*10**18);
        yamhelper.write_balanceOf(DAI, address(cov_user), 10*10**18);

        assertEq(uint256(pool.reserves()), 100*10**18, "reserves");
        assertEq(uint256(pool.utilized()), 0, "utilized");

        cov_user.doBuy(pool, 10**18);
        UmbrellaMetaPool.Protection memory pro = pool.getProtectionInfo(0);

        assertEq(uint(pro.coverageAmount), 10**18,                     "coverage amount");
        assertEq(          uint(pro.paid), 3912712519564800,           "coverage payment");
        assertEq(              pro.holder, address(cov_user),          "coverage holder");
        assertEq(         uint(pro.start), block.timestamp,            "coverage start");
        assertEq(        uint(pro.expiry), block.timestamp + 86400*14, "coverage expiry");
        assertEq(  uint(pro.conceptIndex), 0,                          "coverage concept Index");
        assertTrue(pro.status == UmbrellaMetaPool.Status.Active);

        assertEq(pool.utilized(), uint(pro.coverageAmount), "pool utilized");
        yamhelper.ff(86400*14 + 86400*7 + 1);
        pool.sweep(0);
        pro = pool.getProtectionInfo(0);
        assertTrue(pro.status == UmbrellaMetaPool.Status.Swept);
        UmbrellaMetaPool.CreatorInfo memory creatorInfo = pool.getCreatorInfo();
        UmbrellaMetaPool.ArbiterInfo memory arbiterInfo = pool.getArbiterInfo();
        assertEq(     uint(arbiterInfo.arbiterFeesAvailable), 78254250391296,               "arb fees");
        assertEq(     uint(creatorInfo.creatorFeesAvailable), 39127125195648,               "creator fees");
        assertEq(     uint256(pool.reserves()), 195635625978240 + 100*10**18, "reserves + rollover");
        assertEq(uint256(pool.premiumsAccum()), 3599695517999616,             "premiumsAccum");
        assertEq(   pool.claimablePremiums(me), 3599695517999616,             "claimable");
        uint256 bal_pre = IERC20(DAI).balanceOf(me);
        pool.claimPremiums();
        uint256 bal_post = IERC20(DAI).balanceOf(me);
        assertEq(bal_post, bal_pre + 3599695517999616, "claim");
    }

    function test_ycp_two_providers() public {
        initialize_pool();
        yamhelper.write_balanceOf(DAI, me, 100*10**18);
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.provideCoverage(100*10**18);
        yamhelper.write_balanceOf(DAI, address(cov_user), 10000*10**18);

        assertEq(uint256(pool.reserves()), 100*10**18, "reserves");
        assertEq(uint256(pool.utilized()), 0, "utilized");

        cov_user.doBuy(pool, 10**18);
        UmbrellaMetaPool.Protection memory pro = pool.getProtectionInfo(0);

        assertEq(uint(pro.coverageAmount), 10**18,                     "coverage amount");
        assertEq(          uint(pro.paid), 3912712519564800,           "coverage payment");
        assertEq(              pro.holder, address(cov_user),          "coverage holder");
        assertEq(         uint(pro.start), block.timestamp,            "coverage start");
        assertEq(        uint(pro.expiry), block.timestamp + 86400*14, "coverage expiry");
        assertEq(  uint(pro.conceptIndex), 0,                          "coverage concept Index");
        assertTrue(pro.status == UmbrellaMetaPool.Status.Active);

        assertEq(pool.utilized(), uint(pro.coverageAmount), "pool utilized");
        yamhelper.ff(86400*7);
        cov_user.doCover(pool, 50*10**18);
        yamhelper.ff(86400*7 + 86400*7 + 1);
        pool.sweep(0);
        pro = pool.getProtectionInfo(0);
        address use = address(cov_user);
        assertTrue(pro.status == UmbrellaMetaPool.Status.Swept);
        UmbrellaMetaPool.CreatorInfo memory creatorInfo = pool.getCreatorInfo();
        UmbrellaMetaPool.ArbiterInfo memory arbiterInfo = pool.getArbiterInfo();
        assertEq(     uint(arbiterInfo.arbiterFeesAvailable), 78254250391296,               "arb fees");
        assertEq(     uint(creatorInfo.creatorFeesAvailable), 39127125195648,               "creator fees");
        assertEq(     uint256(pool.reserves()), 195635625978240 + 150*10**18, "reserves + rollover");
        assertEq(uint256(pool.premiumsAccum()), 3599695517999616,             "premiumsAccum");
        assertEq(   pool.claimablePremiums(me), 2699771452503655,             "claimable");
        assertEq(  pool.currentProviderTPS(me), 181440100000000000000000000,  "TPS");
        assertEq(  pool.claimablePremiums(use), 1199898505999872,              "claimable");
        assertEq( pool.currentProviderTPS(use), 60480050000000000000000000,   "TPS");


        uint256 bal_pre = IERC20(DAI).balanceOf(me);
        pool.claimPremiums();
        uint256 bal_post = IERC20(DAI).balanceOf(me);
        assertEq(bal_post, bal_pre + 2699771452503655, "claim");
    }

    function test_ycp_one_claim_two_providers() public {
        initialize_pool();
        yamhelper.write_balanceOf(DAI, me, 100*10**18);
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.provideCoverage(100*10**18);
        yamhelper.write_balanceOf(DAI, address(cov_user), 10000*10**18);


        assertEq(uint256(pool.reserves()), 100*10**18, "reserves");
        assertEq(uint256(pool.utilized()), 0, "utilized");

        cov_user.doBuy(pool, 10**18);
        UmbrellaMetaPool.Protection memory pro = pool.getProtectionInfo(0);

        /* assertEq(uint(pro.coverageAmount), 10**18,                     "coverage amount");
        assertEq(          uint(pro.paid), 3912712519564800,           "coverage payment");
        assertEq(              pro.holder, address(cov_user),          "coverage holder");
        assertEq(         uint(pro.start), block.timestamp,            "coverage start");
        assertEq(        uint(pro.expiry), block.timestamp + 86400*14, "coverage expiry");
        assertEq(  uint(pro.conceptIndex), 0,                          "coverage concept Index");
        assertTrue(pro.status == UmbrellaMetaPool.Status.Active); */

        /* assertEq(pool.utilized(), uint(pro.coverageAmount), "pool utilized"); */
        yamhelper.ff(86400*7 + 1);
        cov_user.doCover(pool, 100*10**18);
        yamhelper.ff(86400*7 + 86400*7 + 1);
        pool.sweep(0);
        pool.premiumsAccum();
        pool.currentTotalTPS();
        pool.currentProviderTPS(me);
        pool.currentProviderTPS(address(cov_user));

        pro = pool.getProtectionInfo(0);
        address use = address(cov_user);
        assertTrue(pro.status == UmbrellaMetaPool.Status.Swept);
        UmbrellaMetaPool.CreatorInfo memory creatorInfo = pool.getCreatorInfo();
        UmbrellaMetaPool.ArbiterInfo memory arbiterInfo = pool.getArbiterInfo();
        assertEq(     uint(arbiterInfo.arbiterFeesAvailable), 78254250391296,               "arb fees");
        assertEq(     uint(creatorInfo.creatorFeesAvailable), 39127125195648,               "creator fees");
        assertEq(     uint256(pool.reserves()), 200*10**18 + 195635625978240,        "reserves + rollover");
        assertEq(uint256(pool.premiumsAccum()), 3599695517999616,             "premiumsAccum");
        assertEq(   pool.claimablePremiums(me), 2159817548874633,             "claimable");
        assertEq(  pool.currentProviderTPS(me), 181440200000000000000000000,  "TPS");
        assertEq(  pool.claimablePremiums(use), 1799847758999808,             "claimable");
        assertEq( pool.currentProviderTPS(use), 120960100000000000000000000,   "TPS");

        uint256 bal_pre = IERC20(DAI).balanceOf(me);
        pool.claimPremiums();
        uint256 bal_post = IERC20(DAI).balanceOf(me);
        assertEq(bal_post, bal_pre + 2159817548874633, "claim");

        cov_user.doBuy(pool, 10**18);
        yamhelper.ff(86400*14 + 86400*7 + 1);
        pool.sweep(1);
        pool.premiumsAccum();
        pool.currentTotalTPS();
        pool.currentProviderTPS(me);
        pool.currentProviderTPS(address(cov_user));
        pool.claimablePremiums(me);
        pool.claimablePremiums(address(cov_user));
        /*
        pro = pool.getProtectionInfo(1);
        assertTrue(pro.status == UmbrellaMetaPool.Status.Swept);
        assertEq(     uint(arbiterInfo.arbiterFeesAvailable), 155735619725952,              "arb fees");
        assertEq(     uint(creatorInfo.creatorFeesAvailable), 77867809862976,               "creator fees");
        assertEq(     uint256(pool.reserves()), 200*10**18,        "reserves + rollover");
        assertEq(uint256(pool.premiumsAccum()), 7163838507393792,             "premiumsAccum");
        assertEq(   pool.claimablePremiums(me), 2600703670279185,             "claimable");
        assertEq(  pool.currentProviderTPS(me), 2*120960100000000000000000000,  "TPS");
        assertEq(  pool.claimablePremiums(use), 2*719939016366398,            "claimable");
        assertEq( pool.currentProviderTPS(use), 3*30240050000000000000000000,   "TPS");
        cov_user.doClaimPremiums(pool);
        pool.claimPremiums();
        pool.premiumsAccum();
        pool.totalProtectionSeconds();
        pool.providers(use);
        pool.providers(me); */
    }

    function test_ycp_scaled_two_providers() public {
        initialize_pool();
        yamhelper.write_balanceOf(DAI, me, 1000000*10**18);
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.provideCoverage(1000000*10**18);
        yamhelper.write_balanceOf(DAI, address(cov_user), 1000000*10**18);

        assertEq(uint256(pool.reserves()), 1000000*10**18, "reserves");
        assertEq(uint256(pool.utilized()), 0, "utilized");

        uint256 rate = pool.getInterestRate(100000*10**18, 1000000*10**18);

        cov_user.doBuy(pool, 100000*10**18);
        UmbrellaMetaPool.Protection memory pro = pool.getProtectionInfo(0);

        assertEq(uint(pro.coverageAmount), 100000*10**18,              "coverage amount");
        assertEq(          uint(pro.paid), 464301369786240000000,      "coverage payment");
        assertEq(              pro.holder, address(cov_user),          "coverage holder");
        assertEq(         uint(pro.start), block.timestamp,            "coverage start");
        assertEq(        uint(pro.expiry), block.timestamp + 86400*14, "coverage expiry");
        assertEq(  uint(pro.conceptIndex), 0,                          "coverage concept Index");
        assertTrue(pro.status == UmbrellaMetaPool.Status.Active);

        assertEq(pool.utilized(), uint(pro.coverageAmount), "pool utilized");
        yamhelper.ff(86400*7);
        cov_user.doCover(pool, 500000*10**18);
        yamhelper.ff(86400*7 + 86400*7 + 1);
        pool.sweep(0);
        /* pro = pool.getProtectionInfo(0); */
        address use = address(cov_user);
        pool.premiumsAccum();
        pool.claimablePremiums(me);
        pool.claimablePremiums(use);



        /* assertTrue(pro.status == UmbrellaMetaPool.Status.Swept);
        assertEq(     uint(arbiterInfo.arbiterFeesAvailable), 9286027395724800000,             "arb fees");
        assertEq(     uint(creatorInfo.creatorFeesAvailable), 4643013697862400000,             "creator fees");
        assertEq(     uint256(pool.reserves()), 1500000*10**18,       "reserves + rollover");
        assertEq(uint256(pool.premiumsAccum()), 427157260203340800000,           "premiumsAccum");
        assertEq(   pool.claimablePremiums(me), 341722578413122011072,           "claimable");
        assertEq(  pool.currentProviderTPS(me), 1209601000000000000000000000000, "TPS");
        assertEq(  pool.claimablePremiums(use), 85430715230408459243,            "claimable");
        assertEq( pool.currentProviderTPS(use), 302400500000000000000000000000,  "TPS");
        uint256 bal_pre = IERC20(DAI).balanceOf(me);
        pool.claimPremiums();
        uint256 bal_post = IERC20(DAI).balanceOf(me);
        assertEq(bal_post, bal_pre + 3599688475726533, "claim"); */
    }


    function test_ycp_withdraw() public {
        initialize_pool();
        yamhelper.write_balanceOf(DAI, me, 100*10**18);
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.provideCoverage(100*10**18);
        pool.initiateWithdraw();
        expect_revert_with(address(pool), "withdraw(uint128)", abi.encode(100*10**18), "withdraw:locked");
        yamhelper.ff(86400*7 + 1);
        pool.withdraw(100*10**18);
        expect_revert_with(address(pool), "withdraw(uint128)", abi.encode(1), "SafeMath: subtraction overflow");
        yamhelper.ff(86400*7 + 1);
        expect_revert_with(address(pool), "withdraw(uint128)", abi.encode(100*10**18), "withdraw:expired");
        pool.provideCoverage(100*10**18);
        pool.initiateWithdraw();
        yamhelper.write_balanceOf(DAI, address(cov_user), 100*10**18);
        pool.reserves();
        cov_user.doBuy(pool, 10**18);
        pool.reserves();
        yamhelper.ff(86400*7 + 1);
        pool.reserves();
        expect_revert_with(address(pool), "withdraw(uint128)", abi.encode(100*10**18), "withdraw:!liquidity");
        pool.reserves();
        set_settling_with_time(uint32(block.timestamp - 86400));
        pool.utilized();
        pool.reserves();
        cov_user.doClaim(pool, 0);
        pool.withdrawUnderlying(99*10**18);
    }


    function test_ycp_premiums() public {
        initialize_pool();
        yamhelper.write_balanceOf(DAI, me, 1000*10**18);
        yamhelper.write_balanceOf(DAI, address(cov_user), 1000*10**18);
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.provideCoverage(100*10**18);
        cov_user.doCover(pool, 100*10**18);
        cov_user.doDetailedBuy(pool, 0, 100*10**18, 86400, 500 * 10**18, block.timestamp + 10);
        yamhelper.ff(86400 + 86400*7 + 1);
        pool.sweep(0);
        pool.premiumsAccum();
        pool.claimPremiums();
        pool.premiumsAccum();
        pool.currentTotalTPS();
        pool.currentProviderTPS(address(cov_user));
        pool.currentProviderTPS(me);
        cov_user.doDetailedBuy(pool, 0, 100*10**18, 86400, 500 * 10**18, block.timestamp + 10);
        yamhelper.ff(86400*13);
        pool.sweep(1);
        pool.premiumsAccum();
        pool.currentTotalTPS();
        pool.currentProviderTPS(address(cov_user));
        pool.currentProviderTPS(me);
        pool.claimPremiums();
        cov_user.doClaimPremiums(pool);
    }


    function test_ycp_buy() public {
        initialize_pool();
        yamhelper.write_balanceOf(DAI, me, 100*10**18);
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.provideCoverage(100*10**18);
        expect_revert_with(
          address(pool),
          "buyProtection(uint8,uint128,uint128,uint128,uint256)",
          abi.encode(
            1,
            1,
            1,
            1,
            1
          ),
          "buy:!deadline"
        );

        expect_revert_with(
          address(pool),
          "buyProtection(uint8,uint128,uint128,uint128,uint256)",
          abi.encode(
            30,
            1,
            1,
            1,
            block.timestamp + 10
          ),
          "buy:!conceptIndex"
        );

        set_settling();
        expect_revert_with(
          address(pool),
          "buyProtection(uint8,uint128,uint128,uint128,uint256)",
          abi.encode(
            0,
            1,
            1,
            1,
            block.timestamp + 10
          ),
          "buy:!pay"
        );
        continue_pool();

        expect_revert_with(
          address(pool),
          "buyProtection(uint8,uint128,uint128,uint128,uint256)",
          abi.encode(
            0,
            101*10**18, // 1 pay token
            86400*14, // 1 week
            5*101*10**18,
            block.timestamp + 10
          ),
          "buy: overutilized"
        );

        expect_revert_with(
          address(pool),
          "buyProtection(uint8,uint128,uint128,uint128,uint256)",
          abi.encode(
            0,
            10**14, // 1 pay token
            86400*14, // 1 week
            5*101*10**18,
            block.timestamp + 10
          ),
          "buy:!pay"
        );

        expect_revert_with(
          address(pool),
          "buyProtection(uint8,uint128,uint128,uint128,uint256)",
          abi.encode(
            0,
            100*10**18, // 1 pay token
            86400*14, // 1 week
            5,
            block.timestamp + 10
          ),
          "buy:!pay"
        );
    }

    function test_ycp_buy_weth() public {
        initialize_eth_pool();
        helper.write_map(WETH, "balanceOf(address)", me, 1000*10**18);
        IERC20(WETH).approve(address(pool), uint(-1));
        WETH9(WETH).withdraw(10*10**18);
        pool.provideCoverage(100*10**18);
        pool.utilized();
        expect_revert_with(
          address(pool),
          "buyProtection(uint8,uint128,uint128,uint128,uint256)",
          abi.encode(
            0,
            100*10**18, // 1 pay token
            86400*14, // 1 week
            500*10**18,
            block.timestamp + 10
          ),
          100,
          "buy:underpayment"
        );
        pool.utilized();
        pool.reserves();
        pool.buyProtection.value(8*10**17)(
          0,
          10**17, // 1 pay token
          86400*14, // 1 week
          8*10**17,
          block.timestamp + 10
        );
    }

    function test_ycp_claim() public {
        initialize_pool();
        helper.write_map(DAI, "balanceOf(address)", me, 1000000*10**18);
        helper.write_map(DAI, "balanceOf(address)", address(cov_user), 1000000*10**18);
        IERC20(DAI).approve(address(pool), uint(-1));
        pool.provideCoverage(100*10**18);
        cov_user.doCover(pool, 100*10**18);
        pool.buyProtection(
          0,
          199*10**18, // 1 pay token
          86400*14, // 1 week
          5*100*10**18,
          block.timestamp + 10
        );
        yamhelper.ff(1);
        set_settling();
        uint256 utilized = pool.utilized();
        uint256 reserves = pool.reserves();
        uint256 bal = IERC20(DAI).balanceOf(me);
        pool.currentTotalTPS();
        pool.claim(0);
        pool.currentTotalTPS();
        UmbrellaMetaPool.Protection memory pro = pool.getProtectionInfo(0);
        assertTrue(pro.status == UmbrellaMetaPool.Status.Claimed);
        assertEq(pool.utilized(), utilized.sub(pro.coverageAmount), "utilized");
        assertEq(pool.reserves(), reserves.sub(pro.coverageAmount), "reserves");
        assertEq(IERC20(DAI).balanceOf(me), bal.add(pro.coverageAmount).add(pro.paid), "reserves");
        continue_pool();
        pool.currentTotalTPS();
        assertEq(pool.balanceOfUnderlying(me), 5*10**17, "bal underlying");
        assertEq(pool.balanceOfUnderlying(address(cov_user)), 5*10**17, "bal underlying");
        pool.provideCoverage(100*10**18);
        assertEq(pool.balanceOfUnderlying(me), 1005*10**17, "bal underlying2");
        assertEq(pool.balanceOfUnderlying(address(cov_user)), 5*10**17, "bal underlying2");
        cov_user.doBuy(pool, 10**18);
        pool.buyProtection(
          0,
          10*10**18, // 1 pay token
          86400*14, // 1 week
          5*100*10**18,
          block.timestamp + 10
        );
        expect_revert_with(
          address(pool),
          "claim(uint256)",
          abi.encode(1),
          "claim:!owner"
        );

        expect_revert_with(
          address(pool),
          "claim(uint256)",
          abi.encode(2),
          "claim:!settlement"
        );
        yamhelper.ff(86400*14 + 86400*7 + 1);
        pool.sweep(2);
        set_settling();
        expect_revert_with(
          address(pool),
          "claim(uint256)",
          abi.encode(2),
          "claim:!active"
        );
        continue_pool();

        pool.buyProtection(
          0,
          10*10**18, // 1 pay token
          86400*14, // 1 week
          5*100*10**18,
          block.timestamp + 100
        );
        set_settling_with_time(uint32(block.timestamp - 10));
        expect_revert_with(
          address(pool),
          "claim(uint256)",
          abi.encode(3),
          "claim:!settlement"
        );
        continue_pool();

        pool.buyProtection(
          0,
          10*10**18, // 1 pay token
          86400, // 1 week
          5*100*10**18,
          block.timestamp + 10
        );
        continue_pool();
    }

    function set_settling() public {
      yamhelper.ff(2);
      pool._setSettling(0, uint32(block.timestamp - 1), false);
    }

    function set_settling_with_time(uint32 time) public {
      pool._setSettling(0, time, false);
    }

    function continue_pool() public {
      yamhelper.ff(86400*14 + 1);
      /* pool.enterCooldown(0); */
      yamhelper.ff(86400*7 + 1);
      /* pool.reactivateConcept(0); */
    }

    function bytesToBytes8(bytes memory b) public pure returns (bytes8) {
        bytes8 out;

        for (uint i = 0; i < 8; i++) {
            out |= bytes8(b[i] & 0xFF) >> (i * 8);
        }
        return out;
    }
}
