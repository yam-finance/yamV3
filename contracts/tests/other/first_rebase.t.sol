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
import { Timelock } from "../../governance/TimeLock.sol";
import { YAMIncentivizer } from "../../incentivizers/YAMIncentives.sol";
import "../../lib/UniswapRouterInterface.sol";


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


contract YAMv3RebaserTest is DSTest {
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


    address me;

    uint256 public constant BASE = 10**18;

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        me = address(this);
    }

    //
    // TESTS
    //

    function test_launched_proposal() public {
        uint256 id = governor.latestProposalIds(me);
        hevm.roll(block.number +  12345);
        GovernorAlpha.ProposalState state = governor.state(id);
        assertTrue(state == GovernorAlpha.ProposalState.Succeeded);

        governor.queue(id);

        hevm.warp(now + timelock.delay());

        governor.execute(id);

        address[] memory pairs = rebaser.getUniSyncPairs();
        assertEq(pairs[1], address(0xe2aAb7232a9545F29112f9e6441661fD6eEB0a5d));
    }

    function test_proposal_scenario() public {
      address[] memory targets = new address[](1);
      targets[0] = address(rebaser); // rebaser
      uint256[] memory values = new uint256[](1);
      values[0] = 0; // dont send eth
      string[] memory signatures = new string[](1);
      signatures[0] = "addSyncPairs(address[],address[])"; //function to call
      bytes[] memory calldatas = new bytes[](1);
      address[] memory unis = new address[](1);
      address[] memory bal = new address[](0);
      unis[0] = address(0xe2aAb7232a9545F29112f9e6441661fD6eEB0a5d);
      calldatas[0] = abi.encode(unis, bal); // [[[uniToAdd],[balToAdd]]]
      string memory description = "Have rebaser sync() uniswap YAM/ETH pair";
      governor.propose(
        targets,
        values,
        signatures,
        calldatas,
        description
      );

      uint256 id = governor.latestProposalIds(me);

      (
          address[] memory post_targets,
          uint[] memory post_values,
          string[] memory post_signatures,
          bytes[] memory post_calldatas
      ) = governor.getActions(id);

      emit Logger(post_calldatas[0]);

      vote_pos_latest();

      hevm.roll(block.number +  12345);


      GovernorAlpha.ProposalState state = governor.state(id);
      assertTrue(state == GovernorAlpha.ProposalState.Succeeded);

      governor.queue(id);

      hevm.warp(now + timelock.delay());

      governor.execute(id);

      address[] memory pairs = rebaser.getUniSyncPairs();
      assertEq(pairs[1], unis[0]);
    }

    function vote_pos_latest() public {
        hevm.roll(block.number + 10);
        uint256 id = governor.latestProposalIds(me);
        governor.castVote(id, true);
    }
}
