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
import { HEVMHelpers, User } from "../HEVMHelpers.sol";

interface Hevm {
    function warp(uint) external;
    function roll(uint) external;
    function store(address,bytes32,bytes32) external;
    function load(address,bytes32) external;
    function origin(address) external;
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

    event Actions(address[], uint[], string[], bytes[]);

    using SafeMath for uint256;

    Hevm hevm;

    HEVMHelpers helper;

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint(keccak256('hevm cheat code'))));

    // V3
    YAMDelegator yamV3 = YAMDelegator(0x0AaCfbeC6a24756c20D41914F2caba817C0d8521);
    YAMRebaser rebaser = YAMRebaser(0x1fB361f274f316d383B94D761832AB68099A7B00); // rebaser contract
    GovernorAlpha governor = GovernorAlpha(0x62702387C2a26C903985e9D078d18C45ACaE0908); // protocol governor
    Timelock timelock = Timelock(0x8b4f1616751117C38a0f84F9A146cca191ea3EC5); // governance owner

    GovernorAlpha public governor2 = GovernorAlpha(0x78BdD33e95ECbcAC16745FB28DB0FFb703344026);

    UniRouter2 uniRouter = UniRouter2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    address yyCRV = address(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);

    address uniFact = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    address me;

    uint256 public constant BASE = 10**18;

    User user;

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));
        /* governor2 = new GovernorAlpha(address(timelock), address(yamV3)); */
        me = address(this);
        uint256[] memory slots = new uint256[](1);
        address[] memory contracts = new address[](1);
        slots[0] = 0;
        contracts[0] = yyCRV;
        helper = new HEVMHelpers();
        user = new User();
    }

    //
    // TESTS
    //

    function test_rebaseTuning() public {
        helper.makeQuorumReady(yamV3, me, user);


        address[] memory targets = new address[](2);
        targets[0] = address(rebaser); // rebaser
        targets[1] = address(rebaser); // rebaser
        uint256[] memory values = new uint256[](2);
        values[0] = 0; // dont send eth
        values[1] = 0; // dont send eth
        string[] memory signatures = new string[](2);
        signatures[0] = "setRebaseLag(uint256)"; //function to call
        signatures[1] = "setMaxSlippageFactor(uint256)"; //function to call
        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encode(uint256(20));
        calldatas[1] = abi.encode(uint256(2597836 * 10**10));
        string memory description = "Set RebaseLag to 20, Max Slippage to 5%";
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
        emit Actions( post_targets,
                      post_values,
                      post_signatures,
                      post_calldatas);
        emit Logger(post_calldatas[0]);
        emit Logger(post_calldatas[1]);

        vote_pos_latest();

        hevm.roll(block.number +  12345);


        GovernorAlpha.ProposalState state = governor2.state(id);
        assertTrue(state == GovernorAlpha.ProposalState.Succeeded);

        governor2.queue(id);

        hevm.warp(now + timelock.delay());

        governor2.execute(id);

        uint256 newLag = rebaser.rebaseLag();
        assertEq(newLag, uint256(20));
        uint256 newM = rebaser.maxSlippageFactor();
        assertEq(newM, uint256(2597836 * 10**10));
        assertTrue(false);
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


    function pos_rebase() internal {
      hevm.warp(now + 6 hours);
      uint256 twap = rebaser.getCurrentTWAP();
      while (twap <= 110 * 10**16) {
        push_price_up();
        hevm.warp(now + 6 hours);
        twap = rebaser.getCurrentTWAP();
      }

      assertTrue(rebaser.getCurrentTWAP() > 105 * 10**16);

      hevm.warp(now + 12 hours + 1);

      uint256 offset = rebaser.rebaseWindowOffsetSec();
      uint256 interval = rebaser.minRebaseTimeIntervalSec();
      uint256 waitTime;
      if (now % interval > offset) {
        waitTime = (interval - (now % interval)) + offset;
      } else {
        waitTime = offset - (now % interval);
      }
      hevm.warp(now + waitTime + 1);


      assertTrue(rebaser.inRebaseWindow());
      rebaser.rebase();
      assertTrue(false);
    }

    function push_price_up() internal {
        if (IERC20(yyCRV).balanceOf(me) < 1000000*10**18) {
            helper.arbitaryWriteBalance(yyCRV, me, 12008925819614629174706176);
        }
        address[] memory path = new address[](2);
        path[0] = yyCRV;
        path[1] = address(yamV3);
        IERC20(yyCRV).approve(address(uniRouter), uint256(-1));
        yamV3.approve(address(uniRouter), uint256(-1));
        uniRouter.swapExactTokensForTokens(
            1000000*10**18,
            1,
            path,
            me,
            now + 60
        );
    }
}
