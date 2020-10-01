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
    using SafeMath for uint256;


    // --- constants
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint(keccak256('hevm cheat code'))));
    uint256 public constant BASE = 10**18;

    // --- yam ecosystem
    YAMDelegator yamV3 = YAMDelegator(0x0AaCfbeC6a24756c20D41914F2caba817C0d8521);
    YAMRebaser rebaser = YAMRebaser(0x1fB361f274f316d383B94D761832AB68099A7B00); // rebaser contract
    Timelock timelock = Timelock(0x8b4f1616751117C38a0f84F9A146cca191ea3EC5); // governance owner
    GovernorAlpha public governor = GovernorAlpha(0x78BdD33e95ECbcAC16745FB28DB0FFb703344026);

    // --- uniswap
    UniRouter2 uniRouter = UniRouter2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address uniFact = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    // --- tokens
    address yyCRV = address(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);

    // --- helpers
    Hevm hevm;
    HEVMHelpers helper;
    User user;
    address me;

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));
        me = address(this);
        user = new User();
        helper = new HEVMHelpers();
    }

    // --- tests
}
