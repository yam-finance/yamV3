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

contract User {
}



contract YAMv3GovTest is DSTest {
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

    GovernorAlpha public governor2 = GovernorAlpha(0x78BdD33e95ECbcAC16745FB28DB0FFb703344026);

    address me;

    uint256 public constant BASE = 10**18;

    User user;

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));
        /* governor2 = new GovernorAlpha(address(timelock), address(yamV3)); */
        me = address(this);
        user = new User();
    }

    //
    // TESTS
    //

    function test_newgov() public {
        address[] memory targets = new address[](1);
        targets[0] = address(timelock); // rebaser
        uint256[] memory values = new uint256[](1);
        values[0] = 0; // dont send eth
        string[] memory signatures = new string[](1);
        signatures[0] = "setPendingAdmin(address)"; //function to call
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encode(address(governor2));
        string memory description = "Reinstate guardian with reduced functionality (cancel only)";
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
        post_targets; post_values; post_signatures; // ssh

        emit Logger(post_calldatas[0]);

        vote_pos_latest();

        /* hevm.roll(block.number +  12345); */


        /* GovernorAlpha.ProposalState state = governor2.state(id);
        assertTrue(state == GovernorAlpha.ProposalState.Succeeded); */

        governor2.cancel(id);

        GovernorAlpha.ProposalState state = governor2.state(id);
        assertTrue(state == GovernorAlpha.ProposalState.Canceled);

        /* governor.queue(id); */

        /* hevm.warp(now + timelock.delay());

        governor.execute(id);

        address newPending = timelock.pendingAdmin();
        assertEq(newPending, address(governor2));
        governor2.__acceptAdmin();
        address admin = timelock.admin();
        assertEq(admin, address(governor2));
        assertTrue(false); */
    }

    function test_moveDelegate() public {
        uint256 votes = yamV3.getCurrentVotes(me);
        uint256 votes3 = yamV3.getCurrentVotes(address(user));
        yamV3.delegate(address(user));
        uint256 votes2 = yamV3.getCurrentVotes(me);
        uint256 votes4 = yamV3.getCurrentVotes(address(user));
        assertEq(votes, votes2);
        assertEq(votes3, votes4);
    }

    function vote_pos_latest() public {
        hevm.roll(block.number + 10);
        uint256 id = governor2.latestProposalIds(me);
        governor2.castVote(id, true);
    }
}
