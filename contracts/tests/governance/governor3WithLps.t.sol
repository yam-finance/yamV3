// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../../lib/SafeMath.sol";
import "../../lib/SafeERC20.sol";
import { DSTest } from "../../lib/test.sol";
import { YAMDelegator } from "../../token/YAMDelegator.sol";
import { YAMDelegate } from "../../token/YAMDelegate.sol";
import { Migrator } from "../../migrator/Migrator.sol";
import { YAMRebaser } from "../../rebaser/YAMRebaser.sol";
import { YAMReserves } from "../../reserves/YAMReserves.sol";
import { GovernorAlpha } from "../../governance/YAMGovernorAlpha.sol";
import { DualGovernorAlpha } from "../../governance/YAMGovernorAlphaWithLps.sol";
import { Timelock } from "../../governance/TimeLock.sol";
import { YAMIncentivizer } from "../../incentivizers/YAMIncentives.sol";
import { YAMIncentivizerWithVoting } from "../../incentivizers/YAMIncentivesWithVoting.sol";
import { HEVMHelpers, User } from "../HEVMHelpers.sol";
import "../../lib/UniswapRouterInterface.sol";
import "../../lib/IUniswapV2Pair.sol";

interface Hevm {
    function warp(uint) external;
    function roll(uint) external;
    function store(address,bytes32,bytes32) external;
}

interface YAMv2 {
    function decimals() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function approve(address,uint) external returns (bool);
}

interface YYCRV {
  function deposit(uint256 _amount) external;
  function withdraw(uint256 shares) external;
}



contract YAMv3Test is DSTest {
    event Logger(bytes);

    using SafeMath for uint256;

    Hevm hevm;
    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint(keccak256('hevm cheat code'))));

    // V3
    YAMDelegator yamV3 = YAMDelegator(0x0AaCfbeC6a24756c20D41914F2caba817C0d8521);
    YAMRebaser rebaser = YAMRebaser(0x1fB361f274f316d383B94D761832AB68099A7B00); // rebaser contract
    GovernorAlpha governor = GovernorAlpha(0x62702387C2a26C903985e9D078d18C45ACaE0908); // protocol governor
    Timelock timelock = Timelock(0x8b4f1616751117C38a0f84F9A146cca191ea3EC5); // governance owner
    YAMIncentivizer incentivizer = YAMIncentivizer(0x5b0501F7041120d36Bc8c6DC3FAeA0b74b32a0Ed);
    YAMIncentivizerWithVoting voting_inc; // = YAMIncentivizerWithVoting(0x5b0501F7041120d36Bc8c6DC3FAeA0b74b32a0Ed);

    address yyCRV = address(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);

    address uniFact = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    GovernorAlpha public governor2 = GovernorAlpha(0x78BdD33e95ECbcAC16745FB28DB0FFb703344026);

    UniRouter2 uniRouter = UniRouter2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    DualGovernorAlpha public governor3;

    address me;

    uint256 public constant BASE = 10**18;

    User user;

    HEVMHelpers helper;

    YAMDelegate new_impl;

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));
        governor3 = new DualGovernorAlpha(address(timelock), address(yamV3));
        voting_inc = new YAMIncentivizerWithVoting();
        new_impl = new YAMDelegate();

        me = address(this);
        user = new User();
        uint256[] memory slots = new uint256[](1);
        address[] memory contracts = new address[](1);
        slots[0] = 0;
        contracts[0] = yyCRV;
        helper = new HEVMHelpers();
    }

    //
    // TESTS
    //

    function newIncentivizer() public {
      voting_inc.setRewardDistribution(me);
      address[] memory targets = new address[](1);
      targets[0] = address(yamV3); // rebaser
      uint256[] memory values = new uint256[](1);
      values[0] = 0; // dont send eth
      string[] memory signatures = new string[](1);
      signatures[0] = "_setIncentivizer(address)"; //function to call
      bytes[] memory calldatas = new bytes[](1);
      calldatas[0] = abi.encode(address(voting_inc));
      string memory description = "new incentivizer";
      governor2.propose(
        targets,
        values,
        signatures,
        calldatas,
        description
      );

      uint256 id = governor2.latestProposalIds(me);

      (
          address[] memory post_targets,
          uint[] memory post_values,
          string[] memory post_signatures,
          bytes[] memory post_calldatas
      ) = governor2.getActions(id);

      emit Logger(post_calldatas[0]);

      vote_pos_latest_gov2();

      hevm.roll(block.number +  12345);


      GovernorAlpha.ProposalState state = governor2.state(id);
      assertTrue(state == GovernorAlpha.ProposalState.Succeeded);

      governor2.queue(id);

      hevm.warp(now + timelock.delay());

      governor2.execute(id);

      address newInc = yamV3.incentivizer();
      assertEq(newInc, address(voting_inc));
      assertEq(voting_inc.rewardDistribution(), me);
      voting_inc.notifyRewardAmount(0);
      voting_inc.setRewardDistribution(address(timelock));
      voting_inc.transferOwnership(address(timelock));
    }


    function newImpl() public {
      address[] memory targets = new address[](2);
      targets[0] = address(yamV3);
      targets[1] = address(yamV3);
      uint256[] memory values = new uint256[](2);
      values[0] = 0; // dont send eth
      values[1] = 0;
      string[] memory signatures = new string[](2);
      signatures[0] = "_setImplementation(address,bool)"; //function to call
      signatures[1] = "delegateToImplementation(bytes)";
      bytes[] memory calldatas = new bytes[](2);
      calldatas[0] = abi.encode(address(voting_inc));
      address yyCRVPool = pairFor(uniFact, address(yamV3), yyCRV);
      calldatas[1] = abi.encodeWithSignature("assignSelfDelegate(address)", yyCRVPool);
      string memory description = "New token logic and assign yyCRVPool delegate to self";
      governor2.propose(
        targets,
        values,
        signatures,
        calldatas,
        description
      );

      uint256 id = governor2.latestProposalIds(me);

      (
          address[] memory post_targets,
          uint[] memory post_values,
          string[] memory post_signatures,
          bytes[] memory post_calldatas
      ) = governor2.getActions(id);

      emit Logger(post_calldatas[0]);

      vote_pos_latest_gov2();

      hevm.roll(block.number +  12345);


      GovernorAlpha.ProposalState state = governor2.state(id);
      assertTrue(state == GovernorAlpha.ProposalState.Succeeded);

      governor2.queue(id);

      hevm.warp(now + timelock.delay());

      governor2.execute(id);

      address newInc = yamV3.incentivizer();
      assertEq(newInc, address(voting_inc));
    }

    function test_newgov3() public {

        assertTrue(false);
        helper.arbitaryWriteBalance(yyCRV, me, 12008925819614629174706176);
        helper.makeQuorumReady(yamV3, me, user);
        newImpl();


        /* newIncentivizer();

        helper.makeQuorumReady(yamV3, me, user);
        address yyCRVPool = pairFor(uniFact, address(yamV3), yyCRV);
        // set to 0 balance
        helper.arbitaryWriteBalance(yyCRV, yyCRVPool, 0);
        helper.writeBalance(yamV3, yyCRVPool, 0);
        helper.manualCheckpoint(yamV3, yyCRVPool, yamV3.numCheckpoints(yyCRVPool), 0);

        joinYYCRV_YAMPool();

        uint256 bal = IERC20(yyCRVPool).balanceOf(me);
        IERC20(yyCRVPool).approve(address(voting_inc), uint256(-1));
        voting_inc.stake(bal);
        bal = voting_inc.balanceOf(me);
        assertEq(bal, 9);
        hevm.roll(block.number + 10);
        assertEq(yamV3.getPriorVotes(yyCRVPool, block.number - 1), 10);
        uint256 votes = voting_inc.getPriorVotes(me, block.number - 1);
        assertEq(votes,11); */


        /* address[] memory targets = new address[](1);
        targets[0] = address(timelock); // rebaser
        uint256[] memory values = new uint256[](1);
        values[0] = 0; // dont send eth
        string[] memory signatures = new string[](1);
        signatures[0] = "setPendingAdmin(address)"; //function to call
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encode(address(governor3));
        string memory description = "Allow LP stakers to vote";
        governor2.propose(
          targets,
          values,
          signatures,
          calldatas,
          description
        );

        uint256 id = governor2.latestProposalIds(me);

        (
            address[] memory post_targets,
            uint[] memory post_values,
            string[] memory post_signatures,
            bytes[] memory post_calldatas
        ) = governor2.getActions(id);

        emit Logger(post_calldatas[0]);

        vote_pos_latest_gov2();

        hevm.roll(block.number +  12345);


        GovernorAlpha.ProposalState state = governor2.state(id);
        assertTrue(state == GovernorAlpha.ProposalState.Succeeded);

        governor2.queue(id);

        hevm.warp(now + timelock.delay());

        governor2.execute(id);

        address newPending = timelock.pendingAdmin();
        assertEq(newPending, address(governor3));
        governor3.__acceptAdmin();
        address admin = timelock.admin();
        assertEq(admin, address(governor3)); */


    }

    function vote_pos_latest_gov2() public {
        hevm.roll(block.number + 10);
        uint256 id = governor2.latestProposalIds(me);
        governor2.castVote(id, true);
    }

    function vote_pos_latest_gov3() public {
        hevm.roll(block.number + 10);
        uint256 id = governor3.latestProposalIds(me);
        governor3.castVote(id, true);
    }

    function joinYYCRV_YAMPool() internal {
        IERC20(yyCRV).approve(address(uniRouter), uint256(-1));
        yamV3.approve(address(uniRouter), uint256(-1));
        address yyCRVPool = pairFor(uniFact, address(yamV3), yyCRV);
        UniswapPair(yyCRVPool).sync();
        /* (uint256 reserves0, uint256 reserves1, ) = UniswapPair(yyCRVPool).getReserves();
        uint256 quote;
        if (address(yamV3) == UniswapPair(yyCRVPool).token0()) {
          quote = uniRouter.quote(10**18, reserves1, reserves0);
        } else {
          quote = uniRouter.quote(10**18, reserves0, reserves1);
        } */

        assertEq(IERC20(yyCRV).balanceOf(me), 0);
        assertEq(yamV3.balanceOf(me) / 2, 0);

        uniRouter.addLiquidity(
            address(yamV3),
            yyCRV,
            yamV3.balanceOf(me) / 2, // equal amounts
            yamV3.balanceOf(me) / 2, // * quote / 10**18,
            1,
            1,
            me,
            now + 60
        );
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(
        address factory,
        address token0,
        address token1
    )
        internal
        pure
        returns (address pair)
    {
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }

}
