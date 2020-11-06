// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../test_tests/base.t.sol";
import { YAMIncentivizerWithVoting } from "./YAMIncentivesWithVoting.sol";
import { DualGovernorAlpha } from "./YAMGovernorAlphaWithLps.sol";
import { YAMDelegate2 } from "./YAMDelegate.sol";
import { YAMRebaser2 } from "./YAMRebaserEth.sol";
import { YAMReserves2 } from "../OTC/YAMReserves2.sol";

contract Prop2 is YAMv3Test {


    YAMIncentivizerWithVoting voting_inc;
    DualGovernorAlpha gov3;
    YAMDelegate2 new_impl;
    address public constant eth_yam_lp = address(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c);
    YAMRebaser2 eth_rebaser;
    address public constant eth_usdc_lp = address(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
    address public masterchef = address(0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd);
    address public sushi = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    address public xsushi = address(0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272);
    YAMReserves2 public r2_onchain = YAMReserves2(0x97990B693835da58A281636296D2Bf02787DEa17);


    DualGovernorAlpha gov3_onchain = DualGovernorAlpha(0xEDf7C3D4CB2e89506C1469709073025d09D47bDd);
    YAMIncentivizerWithVoting inc_onchain = YAMIncentivizerWithVoting(0x6eBF85F830e7D5b3D01Eb64e34A1003223942EAD);
    YAMRebaser2 eth_rebaser_onchain = YAMRebaser2(0xD93f403b432d39aa0f736C2021bE6051d85a1D55);
    YAMDelegate2 impl_onchain = YAMDelegate2(0x209Ddd6b50f748b6EAA25A2793341566492B2526);

    function setUp() public {
        setUpCore();
        /* setup_new_inc();
        setup_new_gov();
        new_impl = new YAMDelegate2();
        setup_new_rebaser(); */
    }


    function test_onchain_prop_bug() public {
      GovernorAlpha gov = GovernorAlpha(timelock.admin());
      gov.execute(5);

      uint256 lut = inc_onchain.lastUpdateTime();

      uint256 printed_lp =  990*10**18;
      yamhelper.write_balanceOf(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c, me, printed_lp);
      IERC20(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c).approve(address(inc_onchain), uint(-1));
      yamhelper.ff(86400);
      inc_onchain.stake(printed_lp);

      uint256 lut2 = inc_onchain.lastUpdateTime();
      assertEq(lut, lut2);
    }

    function test_onchain_prop() public {
      assertTrue(false);
      address[] memory targets = new address[](9);
      uint256[] memory values = new uint256[](9);
      string[] memory signatures = new string[](9);
      bytes[] memory calldatas = new bytes[](9);
      string memory description = "Update impl, gov, rebaser, LP, & ETH OTC purchase";

      add_rebaser_to_prop(address(eth_rebaser_onchain), address(r2_onchain), targets, signatures, calldatas);
      add_gov_to_prop(address(gov3_onchain), targets, signatures, calldatas);
      add_impl_to_prop(address(impl_onchain), targets, signatures, calldatas);
      add_LP_to_prop(address(inc_onchain), address(gov3_onchain), targets, signatures, calldatas);
      add_OTC_to_prop(
          address(0x97a7E840D05Ec436A2d7FE3b5408f89467174dE6),
          215518 * 10**18,
          address(yyCRV),
          address(WETH),
          false,
          targets,
          signatures,
          calldatas
      );


      address prev_inc = yamV3.incentivizer();

      yamhelper.getQuorum(yamV3, me);

      roll_prop(
        targets,
        values,
        signatures,
        calldatas,
        description
      );

      gov3_onchain.__acceptAdmin();

      check_rebaser_parity(address(eth_rebaser_onchain), address(rebaser), address(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c), address(0x397FF1542f962076d0BFE58eA045FfA2d347ACa0));
      address[] memory incentivizers = new address[](1);
      incentivizers[0] = address(inc_onchain);
      checkGov(address(gov3_onchain), incentivizers);
      checkImpl();
      checkOTC(
          address(r2_onchain),
          5*10**16,
          address(timelock),
          address(timelock),
          address(0x9346C20186D1794101B8517177A1b15c49c9ff9b),
          address(0),
          true,
          address(0x97a7E840D05Ec436A2d7FE3b5408f89467174dE6)
      );
      checkLP(address(inc_onchain), prev_inc, address(gov3_onchain), 11242530, 1604995200, 5000 * 10**18);
/*
      yamhelper.ff(inc_onchain.starttime() - block.timestamp);

      uint256 printed_lp =  990*10**18;
      yamhelper.write_balanceOf(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c, me, printed_lp);

      IERC20(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c).approve(address(inc_onchain), uint(-1));
      uint256 pre_stake = IERC20(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c).balanceOf(masterchef);
      inc_onchain.stake(IERC20(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c).balanceOf(me));
      uint256 post_stake = IERC20(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c).balanceOf(masterchef);

      assertEq(pre_stake + printed_lp, post_stake);

      uint256 poolPower = yamV3.getCurrentVotes(eth_yam_lp);
      uint256 mePower = yamV3.getCurrentVotes(me);
      yamhelper.bing(); // increase block number
      assertEq(inc_onchain.getPriorLPStake(me, block.number - 1), printed_lp);
      uint256 total_voting_pow = yamV3.getCurrentVotes(me) + inc_onchain.getCurrentVotes(me);
      assertEq(total_voting_pow, gov3_onchain.getCurrentVotes(me));
      yamhelper.bing();
      assertEq(total_voting_pow, gov3_onchain.getPriorVotes(me, block.number - 1));

      // -- initialize twap
      set_two_hop_uni_price(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c, 0x397FF1542f962076d0BFE58eA045FfA2d347ACa0, address(yamV3), 120 * 10**16);
      yamhelper.ff(12 hours);
      eth_rebaser_onchain.init_twap();
      yamhelper.ff(12 hours);
      eth_rebaser_onchain.activate_rebasing();
      set_two_hop_uni_price(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c, 0x397FF1542f962076d0BFE58eA045FfA2d347ACa0, address(yamV3), 120 * 10**16);
      yamhelper.ff(12 hours);
      eth_rebaser_onchain.getCurrentTWAP();
      // -- fast forward to rebase
      ff_rebase();

      // -- call rebase
      rebase(eth_rebaser_onchain);

      set_two_hop_uni_price(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c, 0x397FF1542f962076d0BFE58eA045FfA2d347ACa0, address(yamV3), 90 * 10**16);
      ff_rebase();

      // -- call rebase
      rebase(eth_rebaser_onchain);

      ff_rebase();

      // -- call rebase
      rebase(eth_rebaser_onchain);

      // fast forward to
      yamhelper.bong(11242530 - block.number + 1);

      total_voting_pow = yamV3.getCurrentVotes(me) + inc_onchain.getCurrentVotes(me);
      assertEq(total_voting_pow, gov3_onchain.getCurrentVotes(me));
      yamhelper.bing();
      assertEq(total_voting_pow, gov3_onchain.getPriorVotes(me, block.number - 1));

      yamhelper.bing();

      yamhelper.bong(10000);
      yamhelper.ff(10000*14);
      inc_onchain.sweepToXSushi();
      assertTrue(IERC20(xsushi).balanceOf(address(inc_onchain)) > 0); // got xsushi
      yamhelper.write_flat(address(inc_onchain), "owner()", me);
      inc_onchain.sushiToReserves(uint256(-1));
      yamhelper.write_flat(address(inc_onchain), "owner()", address(timelock));
      uint256 sushi_res = IERC20(sushi).balanceOf(address(r2_onchain));
      assertEq(sushi_res, 0);
      inc_onchain.exit(); */
    }

    function rebase(YAMRebaser2 r) public {
      uint256 epoch = r.epoch();
      uint256 pre_scalingFactor = yamV3.yamsScalingFactor();

      assertTrue(r.inRebaseWindow());
      r.rebase();
      assertEq(r.epoch(), epoch + 1);
      assertEq(r.blockTimestampLast(), now);

      uint256 scalingFactor = yamV3.yamsScalingFactor();
      assertTrue(scalingFactor > pre_scalingFactor);

      // there can be rounding errors here
      assertEq(yamV3.totalSupply(), yamV3.initSupply().mul(scalingFactor).div(10**24));
    }



    function setup_new_gov() public {
        address[] memory incentivizers = new address[](1);
        incentivizers[0] = address(0x6eBF85F830e7D5b3D01Eb64e34A1003223942EAD);
        gov3 = new DualGovernorAlpha(address(timelock), address(yamV3), incentivizers);
    }

    function setup_new_rebaser() public {
        // -- fully setup rebaser
        eth_rebaser = new YAMRebaser2(
          address(yamV3), // yam
          WETH, // reserve token
          sushiFact, // uniswap factory
          address(r2_onchain), // reserves contract
          gitcoinGrants, // gitcoin grant multisig
          10**16 // percentage to gitcoin grants
        );

        address[] memory uni_like = new address[](3);
        address[] memory bals = new address[](0);

        uni_like[0] = address(0xb93Cc05334093c6B3b8Bfd29933bb8d5C031caBC); // uni yUSD/YAM
        uni_like[1] = address(0xe2aAb7232a9545F29112f9e6441661fD6eEB0a5d); // uni ETH/YAM
        uni_like[2] = address(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c); // sushi ETH/YAM
        eth_rebaser.addSyncPairs(uni_like, bals);
        eth_rebaser._setPendingGov(address(timelock));
    }

    function setup_new_inc() public {
        voting_inc = new YAMIncentivizerWithVoting();
        voting_inc.setMinBlockBeforeVoting(11242530);
        voting_inc.setRewardDistribution(address(timelock));
        voting_inc.transferOwnership(address(timelock));
    }

    //
    // TESTS
    //

    function test_full_update() public {
        assertTrue(false);
        address[] memory targets = new address[](10);
        uint256[] memory values = new uint256[](10);
        string[] memory signatures = new string[](10);
        bytes[] memory calldatas = new bytes[](10);
        string memory description = "Update impl, gov, rebaser, LP, & ETH OTC purchase";

        add_rebaser_to_prop(address(eth_rebaser), address(r2_onchain), targets, signatures, calldatas);
        add_gov_to_prop(address(gov3), targets, signatures, calldatas);
        add_impl_to_prop(address(new_impl), targets, signatures, calldatas);
        add_LP_to_prop(address(voting_inc), address(gov3), targets, signatures, calldatas);
        add_OTC_to_prop(
            address(0x97a7E840D05Ec436A2d7FE3b5408f89467174dE6),
            215518 * 10**18,
            address(yyCRV),
            address(WETH),
            false,
            targets,
            signatures,
            calldatas
        );


        address prev_inc = yamV3.incentivizer();

        yamhelper.getQuorum(yamV3, me);

        roll_prop(
          targets,
          values,
          signatures,
          calldatas,
          description
        );

        gov3.__acceptAdmin();

        check_rebaser_parity(address(eth_rebaser), address(rebaser), address(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c), address(0x397FF1542f962076d0BFE58eA045FfA2d347ACa0));
        address[] memory incentivizers = new address[](1);
        incentivizers[0] = address(voting_inc);
        checkGov(address(gov3), incentivizers);
        checkImpl();
        checkOTC(
            address(r2_onchain),
            5*10**16,
            address(timelock),
            address(timelock),
            address(0x9346C20186D1794101B8517177A1b15c49c9ff9b),
            address(0),
            true,
            address(0x97a7E840D05Ec436A2d7FE3b5408f89467174dE6)
        );
        checkLP(address(voting_inc), prev_inc, address(gov3), 11242530, 1604995200, 5000 * 10**18);
    }

    function test_rebaser_update() public {
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        string[] memory signatures = new string[](3);
        bytes[] memory calldatas = new bytes[](3);
        string memory description = "Update rebaser";

        add_rebaser_to_prop(address(eth_rebaser), address(r2_onchain), targets, signatures, calldatas);

        yamhelper.getQuorum(yamV3, me);

        roll_prop(
          targets,
          values,
          signatures,
          calldatas,
          description
        );

        check_rebaser_parity(address(eth_rebaser), address(rebaser), address(0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c), address(0x397FF1542f962076d0BFE58eA045FfA2d347ACa0));
    }

    function test_lp_update() public {
        address[] memory targets = new address[](6);
        uint256[] memory values = new uint256[](6);
        string[] memory signatures = new string[](6);
        bytes[] memory calldatas = new bytes[](6);
        string memory description = "Update impl, gov & LP";

        add_gov_to_prop(address(gov3), targets, signatures, calldatas);
        add_impl_to_prop(address(new_impl), targets, signatures, calldatas);
        add_LP_to_prop(address(voting_inc), address(gov3), targets, signatures, calldatas);

        address prev_inc = yamV3.incentivizer();

        yamhelper.getQuorum(yamV3, me);

        roll_prop(
          targets,
          values,
          signatures,
          calldatas,
          description
        );

        gov3.__acceptAdmin();

        address[] memory incentivizers = new address[](1);
        incentivizers[0] = address(voting_inc);
        checkGov(address(gov3), incentivizers);
        checkImpl();
        checkLP(address(voting_inc), prev_inc, address(gov3), 11242000, 1604995200, 5000 * 10**18);
    }



    function add_rebaser_to_prop(
        address rebaser,
        address res,
        address[] memory targets,
        string[] memory sigs,
        bytes[] memory datas
    )
        public
    {
        uint256 ctr;
        for (uint256 i = 0; i < targets.length; i++) {
            if (targets[i] != address(0)) {
              ctr++;
            } else {
              break;
            }
        }
        // -- update reserves
        targets[ctr] = res;
        sigs[ctr] = "_setRebaser(address)";
        datas[ctr] = abi.encode(rebaser);
        // -- update token
        targets[ctr+1] = address(yamV3);
        sigs[ctr+1] = "_setRebaser(address)";
        datas[ctr+1] = abi.encode(rebaser);
        // -- accept gov
        targets[ctr+2] = rebaser;
        sigs[ctr+2] = "_acceptGov()";
    }

    function add_OTC_to_prop(
        address trader,
        uint256 amount,
        address sell,
        address buy,
        bool two_hop,
        address[] memory targets,
        string[] memory sigs,
        bytes[] memory datas
    )
        public
    {
        uint256 ctr;
        for (uint256 i = 0; i < targets.length; i++) {
            if (targets[i] != address(0)) {
              ctr++;
            } else {
              break;
            }
        }

        /// ---- SETUP OTC ---- \\\
        /* targets[ctr] = address(r2_onchain);
        sigs[ctr] = "whitelistWithdrawals(address[],uint256[],address[])";
        address[] memory whos = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory tokens = new address[](1);
        whos[0] = address(otc_onchain);
        amounts[0] = amount;
        tokens[0] = address(sell);
        datas[ctr] = abi.encode(whos, amounts, tokens); */

        targets[ctr] = address(otc_onchain);
        sigs[ctr] = "setup_sale(address,address,address,uint256,uint256,uint256,address,address,address)";


        address uni_1;
        address uni_2;

        if (two_hop) {
          uni_1 = pairFor(sell, WETH);
          uni_2 = pairFor(WETH, buy);
        } else {
          uni_1 = pairFor(sell, buy);
        }

        datas[ctr] = abi.encode(
          address(trader), // trader
          address(sell), // sell_token,
          address(buy), // purchase_token,
          uint256(amount), // sell_amount_,
          uint256(60 * 60), // twap_period,
          uint256(5 * 10**16), // twap_bounds_,
          uni_1, // uniswap1,
          uni_2, // uniswap2, // if two hop
          address(r2_onchain) // reserve_
        );
    }

    function checkOTC(
        address res,
        uint256 twap_bounds,
        address g,
        address pg,
        address uni_1,
        address uni_2,
        bool isSale,
        address trader
    )
        public
    {
        assertEq(trader, otc_onchain.approved_trader(), "otc !trader");
        assertEq(res, otc_onchain.reserve(), "otc.reserve != expected");
        assertEq(otc_onchain.complete(), false, "otc completed");
        assertEq(otc_onchain.gov(), g, "otc !gov");
        assertEq(otc_onchain.pendingGov(), pg, "otc !pendingGov");
        assertEq(otc_onchain.uniswap_pair1(), uni_1, "otc !uni1");
        assertEq(otc_onchain.uniswap_pair2(), uni_2, "otc !uni2");
        assertEq(otc_onchain.isSale(), isSale, "otc !isSale");
        assertEq(otc_onchain.twap_counter(), uint256(0), "twap counter");
        if (otc_onchain.isSale()) {
          assertEq(otc_onchain.purchase_amount(), uint256(0), "otc sale, but non-zero purchase");
          assertEq(
            otc_onchain.sell_amount(),
            IERC20(otc_onchain.reserves_sell_token())
              .allowance(address(otc_onchain.reserve()), address(otc_onchain)),
            "otc sale, sale amount != allowance"
          );
        } else {
          assertEq(otc_onchain.sell_amount(), uint256(0), "otc purchase, but non-zero sale");
          assertTrue(
            otc_onchain.purchase_amount() <=
            IERC20(otc_onchain.reserves_sell_token())
              .allowance(address(otc_onchain.reserve()), address(otc_onchain))
          );
        }
    }

    function check_rebaser_parity(address new_rebaser, address old_rebaser, address expected_trade_pair, address expected_other)
        public
    {
        YAMRebaser2 or = YAMRebaser2(old_rebaser);
        YAMRebaser2 nr = YAMRebaser2(new_rebaser);
        address[] memory osp = or.getUniSyncPairs();
        address[] memory nsp = nr.getUniSyncPairs();
        assertEq(osp.length, nsp.length, "rebaser uni sync length");
        uint256 finds;
        for (uint256 i = 0; i < osp.length; i++) {
          for (uint256 j = 0; j < nsp.length; j++) {
            if (osp[i] == nsp[j]) {
                finds++;
                break;
            }
          }
        }
        assertEq(finds, nsp.length, "rebaser uni sync finds");
        osp = or.getBalGulpPairs();
        nsp = nr.getBalGulpPairs();
        assertEq(osp.length, nsp.length, "rebaser bal sync length");
        finds = 0;
        for (uint256 i = 0; i < osp.length; i++) {
          for (uint256 j = 0; j < nsp.length; j++) {
            if (osp[i] == nsp[j]) {
                finds++;
                break;
            }
          }
        }
        assertEq(finds, nsp.length, "rebaser bal sync finds");
        assertEq(or.targetRate(), nr.targetRate(), "rebaser target rate");
        assertEq(or.rebaseMintPerc(), nr.rebaseMintPerc(), "rebaser mint perc");
        assertEq(or.deviationThreshold(), nr.deviationThreshold(), "rebaser dt");
        assertEq(or.minRebaseTimeIntervalSec(), nr.minRebaseTimeIntervalSec(), "rebaser mrti");
        assertEq(or.yamAddress(), nr.yamAddress(), "rebaser yam");
        assertEq(or.reserveToken(), nr.reserveToken(), "rebaser reservetoken");
        assertEq(or.reservesContract(), nr.reservesContract(), "rebaser reserves");
        assertEq(or.public_goods(), nr.public_goods(), "rebaser pg");
        assertEq(or.public_goods_perc(), nr.public_goods_perc(), "rebaser pgp");
        assertEq(or.maxSlippageFactor(), nr.maxSlippageFactor(), "rebaser msf");
        assertEq(nr.gov(), address(timelock), "rebaser timelock");
        assertEq(nr.trade_pair(), expected_trade_pair, "!trade_pair");
        assertEq(nr.eth_usdc_pair(), expected_other, "!eth_usdc");
        assertEq(YAMReserves2(nr.reservesContract()).rebaser(), new_rebaser, "rebaser-reserves");
        assertEq(YAMDelegate(nr.yamAddress()).rebaser(), new_rebaser, "token-rebaser");
    }

    function checkLP(address incent, address prev_inc, address gov, uint256 minblock, uint256 exp_start, uint256 init) public {
        assertEq(yamV3.incentivizer(), address(incent));
        YAMIncentivizerWithVoting inc = YAMIncentivizerWithVoting(incent);
        YAMIncentivizerWithVoting pre_inc = YAMIncentivizerWithVoting(prev_inc);
        DualGovernorAlpha g = DualGovernorAlpha(gov);
        address[] memory incs = g.getIncentivizers();
        bool found;
        for (uint256 i = 0; i < incs.length; i++) {
          if (incs[i] == incent) {
            found = true;
            break;
          }
        }
        assertEq(found, true, "gov-incentivizers not found");
        assertEq(inc.minBlockBeforeVoting(), minblock, "inc min block");
        assertEq(address(g.timelock()), address(inc.owner()), "inc admin");
        assertEq(pre_inc.breaker(), true, "didnt shutoff prev inc");
        assertEq(inc.starttime(), exp_start, "inc !starttime");
        assertEq(inc.initreward(), init, "inc !init");
        assertEq(yamV3.delegates(address(inc.slp())), address(inc.slp()), "slp !delegate");
        assertEq(inc.initialized(), true, "inc !initialized");
    }

    function add_LP_to_prop(
        address inc,
        address gov,
        address[] memory targets,
        string[] memory sigs,
        bytes[] memory datas
    )
        public
    {
        uint256 ctr;
        for (uint256 i = 0; i < targets.length; i++) {
            if (targets[i] != address(0)) {
              ctr++;
            } else {
              break;
            }
        }
        // -- update incentivizer
        targets[ctr] = address(yamV3);
        sigs[ctr] = "_setIncentivizer(address)";
        datas[ctr] = abi.encode(inc);
        // -- assign self delegate
        targets[ctr+1] = address(yamV3);
        datas[ctr+1] =
          abi.encodeWithSignature("assignSelfDelegate(address)", address(YAMIncentivizerWithVoting(inc).slp()));
        // -- add voting inc
        /* targets[ctr+2] = gov;
        sigs[ctr+2] = "addIncentivizer(address)";
        datas[ctr+2] = abi.encode(inc); */
        // -- notify incentivizer
        targets[ctr+2] = inc;
        sigs[ctr+2] = "notifyRewardAmount(uint256)";
        datas[ctr+2] = abi.encode(uint256(0));
    }


    function checkGov(address g, address[] memory incentivizers) public {
        DualGovernorAlpha gov = DualGovernorAlpha(g);
        assertEq(address(gov.timelock()), address(timelock), "gov timelock");
        assertEq(address(gov.yam()), address(yamV3), "gov yam");
        assertEq(gov.guardian(), address(me), "gov guardian");
        assertEq(gov.proposalCount(), uint256(0), "gov prop count");

        address[] memory gov_incs = gov.getIncentivizers();
        uint256 finds;
        assertEq(incentivizers.length, gov_incs.length, "gov lengths");
        for (uint256 i; i < incentivizers.length; i++) {
            for (uint256 j; j < gov_incs.length; j++) {
                if (gov_incs[j] == incentivizers[i]) {
                    finds++;
                    break;
                }
            }
        }
        assertEq(finds, gov_incs.length, "gov incentivizers");
        assertEq(finds, incentivizers.length, "gov expected incentivizers length");
        assertEq(timelock.admin(), g, "timelock admin");
    }

    function add_gov_to_prop(
        address gov,
        address[] memory targets,
        string[] memory sigs,
        bytes[] memory datas
    )
        public
    {
        uint256 ctr;
        for (uint256 i = 0; i < targets.length; i++) {
            if (targets[i] != address(0)) {
              ctr++;
            } else {
              break;
            }
        }
        // -- update admin
        targets[ctr] = address(timelock);
        sigs[ctr] = "setPendingAdmin(address)";
        datas[ctr] = abi.encode(gov);
    }

    function checkImpl() public {
        assertEq(yamV3.implementation(), address(impl_onchain), "yam impl");
    }

    function add_impl_to_prop(
        address impl,
        address[] memory targets,
        string[] memory sigs,
        bytes[] memory datas
    )
        public
    {
        uint256 ctr;
        for (uint256 i = 0; i < targets.length; i++) {
            if (targets[i] != address(0)) {
              ctr++;
            } else {
              break;
            }
        }
        // -- update impl
        targets[ctr] = address(yamV3);
        sigs[ctr] = "_setImplementation(address,bool,bytes)";
        datas[ctr] = abi.encode(address(impl), false, "");
    }


    function test_stake() public {
        uint256 printed_lp =  990*10**18;
        yamhelper.write_balanceOf(eth_yam_lp, me, printed_lp); // we inflate away most other holders to simulate large number of stakers

        // -- get yam governance
        yamhelper.becomeGovernor(address(yamV3), me);
        yamV3._acceptGov();
        helper.write_flat(address(voting_inc), "owner()", me);

        // -- set new incentivizer
        yamV3._setIncentivizer(address(voting_inc));
        voting_inc.setRewardDistribution(me);
        assertEq(voting_inc.rewardDistribution(), me);
        voting_inc.notifyRewardAmount(0);

        // -- increase approval & stake
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        uint256 pre_stake = IERC20(eth_yam_lp).balanceOf(masterchef);
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 post_stake = IERC20(eth_yam_lp).balanceOf(masterchef);

        assertEq(pre_stake + printed_lp, post_stake);

        /* uint256 poolPower = yamV3.getCurrentVotes(eth_yam_lp);
        uint256 mePower = yamV3.getCurrentVotes(me); */
        yamhelper.bing(); // increase block number
        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);
        voting_inc.exit();
    }

    function test_sweep() public {
        uint256 printed_lp =  990*10**18;
        yamhelper.write_balanceOf(eth_yam_lp, me, printed_lp); // we inflate away most other holders to simulate large number of stakers

        // -- get yam governance
        yamhelper.becomeGovernor(address(yamV3), me);
        yamV3._acceptGov();
        helper.write_flat(address(voting_inc), "owner()", me);

        // -- set new incentivizer
        yamV3._setIncentivizer(address(voting_inc));
        voting_inc.setRewardDistribution(me);
        assertEq(voting_inc.rewardDistribution(), me);
        voting_inc.notifyRewardAmount(0);

        // -- increase approval & stake
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        uint256 pre_stake = IERC20(eth_yam_lp).balanceOf(masterchef);
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 post_stake = IERC20(eth_yam_lp).balanceOf(masterchef);

        assertEq(pre_stake + printed_lp, post_stake);

        /* uint256 poolPower = yamV3.getCurrentVotes(eth_yam_lp);
        uint256 mePower = yamV3.getCurrentVotes(me); */
        yamhelper.bing(); // increase block number
        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);
        yamhelper.bong(10000);
        yamhelper.ff(10000*14);
        voting_inc.sweepToXSushi();
        assertTrue(IERC20(xsushi).balanceOf(address(voting_inc)) > 0); // got xsushi
        voting_inc.exit();

    }

    function test_sushi_to_reserves() public {
        uint256 printed_lp =  990*10**18;
        yamhelper.write_balanceOf(eth_yam_lp, me, printed_lp); // we inflate away most other holders to simulate large number of stakers

        // -- get yam governance
        yamhelper.becomeGovernor(address(yamV3), me);
        yamV3._acceptGov();
        helper.write_flat(address(voting_inc), "owner()", me);

        // -- set new incentivizer
        yamV3._setIncentivizer(address(voting_inc));
        voting_inc.setRewardDistribution(me);
        assertEq(voting_inc.rewardDistribution(), me);
        voting_inc.notifyRewardAmount(0);

        // -- increase approval & stake
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        uint256 pre_stake = IERC20(eth_yam_lp).balanceOf(masterchef);
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 post_stake = IERC20(eth_yam_lp).balanceOf(masterchef);

        assertEq(pre_stake + printed_lp, post_stake);

        /* uint256 poolPower = yamV3.getCurrentVotes(eth_yam_lp);
        uint256 mePower = yamV3.getCurrentVotes(me); */
        yamhelper.bing(); // increase block number
        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);
        yamhelper.bong(10000);
        yamhelper.ff(10000*14);
        voting_inc.sweepToXSushi();
        assertTrue(IERC20(xsushi).balanceOf(address(voting_inc)) > 0); // got xsushi
        voting_inc.sushiToReserves(uint256(-1));
        uint256 sushi_res = IERC20(sushi).balanceOf(address(r2_onchain));
        assertEq(sushi_res, 0);
        voting_inc.exit();
    }

    function test_sushi_emergency() public {
        uint256 printed_lp =  990*10**18;
        yamhelper.write_balanceOf(eth_yam_lp, me, printed_lp); // we inflate away most other holders to simulate large number of stakers

        // -- get yam governance
        yamhelper.becomeGovernor(address(yamV3), me);
        yamV3._acceptGov();
        helper.write_flat(address(voting_inc), "owner()", me);

        // -- set new incentivizer
        yamV3._setIncentivizer(address(voting_inc));
        voting_inc.setRewardDistribution(me);
        assertEq(voting_inc.rewardDistribution(), me);
        voting_inc.notifyRewardAmount(0);

        // -- increase approval & stake
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        uint256 pre_stake = IERC20(eth_yam_lp).balanceOf(masterchef);
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 post_stake = IERC20(eth_yam_lp).balanceOf(masterchef);

        assertEq(pre_stake + printed_lp, post_stake);

        /* uint256 poolPower = yamV3.getCurrentVotes(eth_yam_lp);
        uint256 mePower = yamV3.getCurrentVotes(me); */
        yamhelper.bing(); // increase block number
        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);
        yamhelper.bong(10000);
        yamhelper.ff(10000*14);
        voting_inc.sweepToXSushi();
        assertTrue(IERC20(xsushi).balanceOf(address(voting_inc)) > 0); // got xsushi
        voting_inc.emergencyMasterChefWithdraw();
        voting_inc.exit();
    }

    function test_FullProp() public {
        // -- force verbose
        assertTrue(false);

        address[] memory targets = new address[](9);
        uint256[] memory values = new uint256[](9);
        string[] memory signatures = new string[](9);
        bytes[] memory calldatas = new bytes[](9);
        string memory description = "Proposal round 2";

        // -- update rebaser
        targets[0] = address(yamV3);
        signatures[0] = "_setRebaser(address)";
        calldatas[0] = abi.encode(address(eth_rebaser));
        targets[1] = address(reserves);
        signatures[1] = "_setRebaser(address)";
        calldatas[1] = abi.encode(address(eth_rebaser));

        // -- setting implementation
        targets[2] = address(yamV3);
        signatures[2] = "_setImplementation(address,bool,bytes)";
        calldatas[2] = abi.encode(address(new_impl), false, "");

        // -- assign self delegation for eth/yam pool
        targets[3] = address(yamV3);
        calldatas[3] =
            abi.encodeWithSignature("assignSelfDelegate(address)", eth_yam_lp);
        /* ); */

        // -- turn off old incentivizer
        targets[4] = address(incentivizer);
        signatures[4] = "setBreaker(bool)";
        calldatas[4] = abi.encode(true);

        // -- set new incentivizer
        targets[5] = address(yamV3);
        signatures[5] = "_setIncentivizer(address)";
        calldatas[5] = abi.encode(address(voting_inc));

        // -- initialize incentivizer
        targets[6] = address(voting_inc);
        signatures[6] = "notifyRewardAmount(uint256)";
        calldatas[6] = abi.encode(uint256(0));

        // -- new governor
        targets[7] = address(timelock);
        signatures[7] = "setPendingAdmin(address)";
        calldatas[7] = abi.encode(address(gov3));

        targets[8] = address(eth_rebaser);
        signatures[8] = "_acceptGov()";

        yamhelper.getQuorum(yamV3, me);

        roll_prop(
          targets,
          values,
          signatures,
          calldatas,
          description
        );

        assertEq(reserves.rebaser(), address(eth_rebaser));
        assertEq(yamV3.rebaser(), address(eth_rebaser));

        assertEq(yamV3.implementation(), address(new_impl));

        assertEq(yamV3.delegates(eth_yam_lp), eth_yam_lp);

        assertTrue(incentivizer.breaker());

        assertEq(yamV3.incentivizer(), address(voting_inc));

        assertTrue(voting_inc.initialized());

        assertEq(timelock.pendingAdmin(), address(gov3));

        gov3.__acceptAdmin();

        assertEq(timelock.admin(), address(gov3));

        // -- increase liquidity by 10x
        increase_liquidity(eth_yam_lp, 10);

        // -- initialize twap
        set_two_hop_uni_price(eth_yam_lp, eth_usdc_lp, address(yamV3), 120 * 10**16);
        eth_rebaser.init_twap();
        yamhelper.ff(12 hours);
        eth_rebaser.activate_rebasing();

        // -- fast forward to rebase
        ff_rebase();

        // -- call rebase
        eth_rebaser.rebase();

        yamhelper.bing();

        // -- get LP voting power
        yamhelper.write_balanceOf(eth_yam_lp, me, 990*10**18);
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 total_voting_pow = yamV3.getCurrentVotes(me) + voting_inc.getCurrentVotes(me);
        assertEq(total_voting_pow, gov3.getCurrentVotes(me));
        yamhelper.bing();
        assertEq(total_voting_pow, gov3.getPriorVotes(me, block.number - 1));
    }

    function test_LPVotingPower() public {
        // test includes:
        // -- increase lp token balance
        // -- own existing incentivizer
        // -- set breaker to turn existing incentivizer off
        // -- get yam governance
        // -- update implementation
        // -- set new incentivizer
        // -- increase approval & stake
        // -- check voting power
        // -- add another staker, that is 1% of staking pool
        // -- check voting power
        // -- delegate
        // -- check voting power
        // -- delegate self (checking for duplication)
        // -- check voting power

        // -- force verbose output
        assertTrue(false);

        // -- increase balance
        yamhelper.write_balanceOf(eth_yam_lp, me, 990*10**18); // we inflate away most other holders to simulate large number of stakers

        // -- own existing incentivizer
        helper.write_flat(address(incentivizer), "owner()", me);
        assertEq(incentivizer.owner(), me);

        // -- set breaker to turn it off
        incentivizer.setBreaker(true);

        // -- get yam governance
        yamhelper.becomeGovernor(address(yamV3), me);
        yamV3._acceptGov();

        // -- update implementation
        yamV3._setImplementation(address(new_impl), false, "");
        /* address yyCRVPool = pairFor(uniFact, address(yamV3), yyCRV); */
        yamV3.delegateToImplementation(abi.encodeWithSignature("assignSelfDelegate(address)", eth_yam_lp));
        assertEq(yamV3.delegates(eth_yam_lp), eth_yam_lp);

        // -- set new incentivizer
        yamV3._setIncentivizer(address(voting_inc));
        voting_inc.setRewardDistribution(me);
        assertEq(voting_inc.rewardDistribution(), me);
        voting_inc.notifyRewardAmount(0);

        // -- increase approval & stake
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 poolPower = yamV3.getCurrentVotes(eth_yam_lp);
        uint256 mePower = yamV3.getCurrentVotes(me);
        yamhelper.bing(); // increase block number
        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);

        // -- check voting power
        assertEq(voting_inc.getPriorVotes(me, block.number - 1), poolPower);
        assertEq(gov3.getPriorVotes(me, block.number - 1), poolPower + mePower);
        // -- add another staker, that is 1% of staking pool
        user.doStake(yamhelper, address(voting_inc), 10*10**18);
        yamhelper.bing();

        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);
        assertEq(voting_inc.getPriorLPStake(address(user), block.number - 1), 10*10**18);

        // -- check voting power
        assertEq(voting_inc.getPriorVotes(me, block.number - 1), poolPower * 99 / 100);
        assertEq(voting_inc.getPriorVotes(address(user), block.number - 1), poolPower / 100);

        // -- check delegation
        user.doDelegate(address(voting_inc), me);
        assertEq(voting_inc.delegates(address(user)), me);
        yamhelper.bing();

        // -- check voting power
        assertEq(voting_inc.getPriorVotes(me, block.number - 1), poolPower);
        assertEq(voting_inc.getPriorVotes(address(user), block.number - 1), 0);

        // -- check delegation (no duplicating votes)
        voting_inc.delegate(me);
        assertEq(voting_inc.delegates(me), me);
        yamhelper.bing();

        // -- check voting power
        assertEq(voting_inc.getPriorVotes(me, block.number - 1), poolPower);
        assertEq(voting_inc.getPriorVotes(address(user), block.number - 1), 0);
    }

    function test_LPVotingGov3() public {
        // -- force verbose output
        assertTrue(false);

        // -- increase balances
        yamhelper.write_balanceOf(eth_yam_lp, me, 990*10**18); // we inflate away most other holders to simulate large number of stakers

        // -- own existing incentivizer
        helper.write_flat(address(incentivizer), "owner()", me);
        assertEq(incentivizer.owner(), me);

        // -- set breaker to turn it off
        incentivizer.setBreaker(true);

        // -- get yam governance
        yamhelper.becomeGovernor(address(yamV3), me);
        yamV3._acceptGov();

        // -- update implementation
        yamV3._setImplementation(address(new_impl), false, "");
        /* address yyCRVPool = pairFor(uniFact, address(yamV3), yyCRV); */
        yamV3.delegateToImplementation(abi.encodeWithSignature("assignSelfDelegate(address)", eth_yam_lp));
        assertEq(yamV3.delegates(eth_yam_lp), eth_yam_lp);

        // -- set new incentivizer
        yamV3._setIncentivizer(address(voting_inc));
        voting_inc.setRewardDistribution(me);
        assertEq(voting_inc.rewardDistribution(), me);
        voting_inc.notifyRewardAmount(0);

        // -- increase approval & stake
        IERC20(eth_yam_lp).approve(address(voting_inc), uint(-1));
        voting_inc.stake(IERC20(eth_yam_lp).balanceOf(me));
        uint256 poolPower = yamV3.getCurrentVotes(eth_yam_lp);
        yamhelper.bing(); // increase block number
        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);

        // -- check voting power
        assertEq(voting_inc.getPriorVotes(me, block.number - 1), poolPower);

        // -- add another staker, that is 1% of staking pool
        user.doStake(yamhelper, address(voting_inc), 10*10**18);
        yamhelper.bing();

        assertEq(voting_inc.getPriorLPStake(me, block.number - 1), 990*10**18);
        assertEq(voting_inc.getPriorLPStake(address(user), block.number - 1), 10*10**18);

        // -- check voting power
        assertEq(voting_inc.getPriorVotes(me, block.number - 1), poolPower * 99 / 100);
        assertEq(voting_inc.getPriorVotes(address(user), block.number - 1), poolPower / 100);

        // -- new gov
        helper.write_flat(address(timelock), "admin()", address(gov3));
        assertEq(timelock.admin(), address(gov3));
        yamhelper.becomeGovernor(address(yamV3), address(timelock));
        timelock_accept_gov(address(yamV3));
        assertEq(yamV3.gov(), address(timelock));

        // -- check voting powers
        uint256 total_voting_pow = yamV3.getCurrentVotes(me) + voting_inc.getCurrentVotes(me);
        assertEq(total_voting_pow, gov3.getCurrentVotes(me));
        yamhelper.bing();
        assertEq(total_voting_pow, gov3.getPriorVotes(me, block.number - 1));


        // -- at this point, the new incentivizer is setup
        // the new governor is setup, me has the 99% voting power of the
        // lp pool

        // -- lets test with adding a new sync pair for sushiswap eth/yam

        address[] memory targets = new address[](1);
        targets[0] = address(rebaser); // rebaser
        uint256[] memory values = new uint256[](1);
        values[0] = 0; // dont send eth
        string[] memory signatures = new string[](1);
        signatures[0] = "addSyncPairs(address[],address[])"; //function to call
        bytes[] memory calldatas = new bytes[](1);
        address[] memory unis = new address[](1);
        address[] memory bal = new address[](0);
        unis[0] = address(0x95b54C8Da12BB23F7A5F6E26C38D04aCC6F81820);
        calldatas[0] = abi.encode(unis, bal); // [[[uniToAdd],[balToAdd]]]
        string memory description = "Have rebaser sync() sushiswap YAM/ETH pair";
        roll_prop(targets, values, signatures, calldatas, description);

        address[] memory pairs = rebaser.getUniSyncPairs();
        assertEq(pairs[2], unis[0]);
    }


    function test_EthRebaser() public {
        // -- force verbose output
        /* assertTrue(false); */
        setup_rebaser();

        // increase liquidity by 10x
        increase_liquidity(eth_yam_lp, 10);

        // -- initialize twap
        set_two_hop_uni_price(eth_yam_lp, eth_usdc_lp, address(yamV3), 120 * 10**16);
        eth_rebaser.init_twap();
        yamhelper.ff(12 hours);
        assertEq(eth_rebaser.getCurrentTWAP(), 0);
        eth_rebaser.activate_rebasing();

        // -- fast forward to rebase
        ff_rebase();

        // -- call rebase x4
        eth_rebaser.rebase();
        yamhelper.ff(6 hours);
        assertEq(eth_rebaser.getCurrentTWAP(), 1);

        ff_rebase();
        eth_rebaser.rebase();
        yamhelper.ff(6 hours);
        assertEq(eth_rebaser.getCurrentTWAP(), 2);

        ff_rebase();
        eth_rebaser.rebase();


        set_two_hop_uni_price(eth_yam_lp, eth_usdc_lp, address(yamV3), 90 * 10**16);
        yamhelper.ff(6 hours);
        assertEq(eth_rebaser.getCurrentTWAP(), 3);



        ff_rebase();
        eth_rebaser.rebase();
        yamhelper.ff(6 hours);
        assertEq(eth_rebaser.getCurrentTWAP(), 4);
    }

    function setup_rebaser() public {
        // -- add sync pairs
        address[] memory uni_like = new address[](2);
        address[] memory bals = new address[](0);

        uni_like[0] = address(0x95b54C8Da12BB23F7A5F6E26C38D04aCC6F81820); // sushi eth/yam
        uni_like[1] = address(0xb93Cc05334093c6B3b8Bfd29933bb8d5C031caBC); // yam_yusd
        eth_rebaser.addSyncPairs(uni_like, bals);

        // -- update reserves & yam rebaser
        atomicGov(address(reserves), "_setRebaser(address)", address(eth_rebaser));
        atomicGov(address(yamV3), "_setRebaser(address)", address(eth_rebaser));
    }
}
