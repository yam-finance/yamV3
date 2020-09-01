// SPDX-License-Identifier: MIT

pragma solidity 0.5.15;

import "../lib/SafeMath.sol";
import "../lib/SafeERC20.sol";
import {DSTest} from "../lib/test.sol";
import {YAMDelegator} from "./YAMDelegator.sol";
import {YAMDelegate} from "./YAMDelegate.sol";
import {Migrator} from "../migrator/Migrator.sol";

interface Hevm {
    function warp(uint) external;
    function store(address,bytes32,bytes32) external;
}

interface YAMv2 {
    function decimals() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function approve(address,uint) external returns (bool);
}

contract User {
    function doTransfer(YAMDelegator yamV3, address to, uint256 amount) external {
        yamV3.transfer(to, amount);
    }

    function doMint(YAMDelegator yamV3, address to, uint256 amount) external {
        yamV3.mint(to, amount);
    }

    function doApprove(YAMDelegator yamV3, address spender, uint256 amount) external {
        yamV3.approve(spender, amount);
    }

    function doTransferFrom(YAMDelegator yamV3, address from, uint256 amount) external {
        yamV3.transferFrom(from, address(this), amount);
    }

    function doSetRebaser(YAMDelegator yamV3, address reb) external {
        yamV3._setRebaser(reb);
    }

    function doSetMigrator(YAMDelegator yamV3, address mig) external {
        yamV3._setMigrator(mig);
    }

    function doSetIncentivizer(YAMDelegator yamV3, address inc) external {
        yamV3._setIncentivizer(inc);
    }

    function doSetPendingGov(YAMDelegator yamV3, address pendingGov) external {
        yamV3._setPendingGov(pendingGov);
    }

    function doAcceptGov(YAMDelegator yamV3) external {
        yamV3._acceptGov();
    }

    function doRebase(YAMDelegator yamV3, uint256 epoch, uint256 indexDelta, bool positive) external {
        yamV3.rebase(epoch, indexDelta, positive);
    }

    function doRescuetokens(YAMDelegator yamV3, address token, address to, uint256 amount) external {
        yamV3.rescueTokens(token, to, amount);
    }
}

contract YAMv3Test is DSTest {
    using SafeMath for uint256;

    Hevm hevm;
    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint(keccak256('hevm cheat code'))));

    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    YAMv2 yamV2;

    YAMDelegate delegate;

    YAMDelegator yamV3;

    Migrator migration;

    User user;

    address me;

    uint256 public constant BASE = 10**18;

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        // Cuurrent YAM v2 token
        yamV2 = YAMv2(0xAba8cAc6866B83Ae4eec97DD07ED254282f6aD8A);

        // Create an implementation
        delegate = new YAMDelegate();

        // Create delegator
        yamV3 = new YAMDelegator(
            "YAMv3",
            "YAMv3",
            18,
            0,
            address(delegate),
            ""
        );


        me = address(this);

        assert(yamV3.initSupply() == 0);
        assert(yamV3.totalSupply() == 0);
        assert(yamV3.yamsScalingFactor() == BASE);
        assert(yamV3.balanceOf(me) == 0);

        // Create a new migration for testing
        migration = new Migrator();

        yamV3._setMigrator(address(migration));
        assert(yamV3.migrator() == address(migration));

        // set v3
        migration.setV3Address(address(yamV3));

        migration.delegatorRewardsDone();

        yamV2.approve(address(migration), uint256(-1));

        // Warp to start of migration
        hevm.warp(migration.startTime());

        // get v3 tokens
        migration.migrate();

        // User for testing
        user = new User();
    }

    //
    // TESTS
    //
    function testFail_mint() public {
        // fail
        user.doMint(yamV3, me, 10**18);
    }

    function test_mintMigrator() public {
        yamV3._setMigrator(address(user));
        uint256 starting_bal = yamV3.balanceOfUnderlying(me);
        user.doMint(yamV3, me, 10**18);
        assertEq(yamV3.balanceOfUnderlying(me), starting_bal+10**18);
    }

    function test_mintNormal() public {
        uint256 amount = 10**18;
        uint256 ctr = 1;
        uint256 starting_bal = yamV3.balanceOf(me);

        // rebaser
        yamV3._setRebaser(address(user));
        assertEq(yamV3.rebaser(), address(user));
        user.doMint(yamV3, me, 10**18);
        ctr++;
        assertEq(yamV3.balanceOf(me), starting_bal + amount*ctr);
        yamV3._setRebaser(address(me));
        assertEq(yamV3.rebaser(), address(me));

        // incentivizer
        yamV3._setIncentivizer(address(user));
        assertEq(yamV3.incentivizer(), address(user));
        user.doMint(yamV3, me, 10**18);
        ctr++;
        assertEq(yamV3.balanceOf(me), starting_bal + amount*ctr);
        yamV3._setIncentivizer(address(me));
        assertEq(yamV3.incentivizer(), address(me));

        // gov
        yamV3._setPendingGov(address(user));
        user.doAcceptGov(yamV3);
        user.doMint(yamV3, me, 10**18);
        ctr++;
        assertEq(yamV3.balanceOf(me), starting_bal + amount*ctr);
    }

    function test_transfer() public {
        uint256 scalingFactor = yamV3.yamsScalingFactor();

        uint256 amount = 10**18;
        uint256 yamAmount = amount.mul(10**24).div(scalingFactor);

        uint256 pre_balance = yamV3.balanceOf(me);
        uint256 pre_underlying = yamV3.balanceOfUnderlying(me);
        yamV3.transfer(me, amount);
        uint256 balance = yamV3.balanceOf(me);
        uint256 underlying = yamV3.balanceOfUnderlying(me);
        assertEq(pre_balance, balance);
        assertEq(pre_underlying, underlying);

        pre_balance = yamV3.balanceOf(me);
        pre_underlying = yamV3.balanceOfUnderlying(me);
        yamV3.transfer(address(user), amount);
        balance = yamV3.balanceOf(me);
        underlying = yamV3.balanceOfUnderlying(me);
        uint256 other_balance = yamV3.balanceOf(address(user));
        uint256 other_underlying= yamV3.balanceOfUnderlying(address(user));
        assertEq(pre_balance - amount, balance);
        assertEq(other_balance, amount);
        assertEq(pre_underlying - yamAmount, underlying);
    }

    function testFail_transfer() public {
        // no balance
        user.doTransfer(yamV3, me, 10**18);
    }

    function test_transferFrom() public {
        uint256 scalingFactor = yamV3.yamsScalingFactor();

        uint256 amount = 10**18;
        uint256 yamAmount = amount.mul(10**24).div(scalingFactor);

        yamV3.approve(address(user), uint256(-1));

        uint256 pre_balance = yamV3.balanceOf(me);
        uint256 pre_underlying = yamV3.balanceOfUnderlying(me);
        user.doTransferFrom(yamV3, me, amount);
        uint256 balance = yamV3.balanceOf(me);
        uint256 underlying = yamV3.balanceOfUnderlying(me);
        uint256 other_balance = yamV3.balanceOf(address(user));
        uint256 other_underlying= yamV3.balanceOfUnderlying(address(user));
        assertEq(pre_balance - amount, balance);
        assertEq(other_balance, amount);
        assertEq(pre_underlying - yamAmount, underlying);
    }

    function testFail_transferFrom() public {
        // fail allowance
        user.doTransferFrom(yamV3, me, 10**18);
    }

    function test_increaseAllowance() public {
        yamV3.increaseAllowance(address(user), 100);
        uint256 allowance = yamV3.allowance(me, address(user));
        assertEq(allowance, 100);
    }

    function test_Permit() public {
        uint nonce = 0;
        uint deadline = 0;
        address cal = 0x29C76e6aD8f28BB1004902578Fb108c507Be341b;
        address del = 0xdd2d5D3f7f1b35b7A0601D6A00DbB7D44Af58479;
        bytes32 r = 0xc7a9f6e53ade2dc3715e69345763b9e6e5734bfe6b40b8ec8e122eb379f07e5b;
        bytes32 s = 0x14cb2f908ca580a74089860a946f56f361d55bdb13b6ce48a998508b0fa5e776;
        uint8 v = 27;
        bytes32 _r = 0x64e82c811ee5e912c0f97ac1165c73d593654a6fc434a470452d8bca6ec98424;
        bytes32 _s = 0x5a209fe6efcf6e06ec96620fd968d6331f5e02e5db757ea2a58229c9b3c033ed;
        uint8 _v = 28;

        uint256 amount = 10**18;

        yamV3.transfer(cal, amount);
        assertEq(yamV3.nonces(cal), 0);
        assertEq(yamV3.allowance(cal, del), 0);
        yamV3.permit(cal, del, 0, 0, true, v, r, s);
        assertEq(yamV3.allowance(cal, del), uint(-1));
        assertEq(yamV3.nonces(cal),1);
    }

    function test_FailPermitAddress0() public {
        uint nonce = 0;
        uint deadline = 0;
        address cal = 0x29C76e6aD8f28BB1004902578Fb108c507Be341b;
        address del = 0xdd2d5D3f7f1b35b7A0601D6A00DbB7D44Af58479;
        bytes32 r = 0xc7a9f6e53ade2dc3715e69345763b9e6e5734bfe6b40b8ec8e122eb379f07e5b;
        bytes32 s = 0x14cb2f908ca580a74089860a946f56f361d55bdb13b6ce48a998508b0fa5e776;
        uint8 v = 27;
        bytes32 _r = 0x64e82c811ee5e912c0f97ac1165c73d593654a6fc434a470452d8bca6ec98424;
        bytes32 _s = 0x5a209fe6efcf6e06ec96620fd968d6331f5e02e5db757ea2a58229c9b3c033ed;
        uint8 _v = 28;
        v = 0;
        yamV3.permit(address(0), del, 0, 0, true, v, r, s);
    }

    function test_PermitWithExpiry() public {
        uint nonce = 0;
        uint deadline = 0;
        address cal = 0x29C76e6aD8f28BB1004902578Fb108c507Be341b;
        address del = 0xdd2d5D3f7f1b35b7A0601D6A00DbB7D44Af58479;
        bytes32 r = 0xc7a9f6e53ade2dc3715e69345763b9e6e5734bfe6b40b8ec8e122eb379f07e5b;
        bytes32 s = 0x14cb2f908ca580a74089860a946f56f361d55bdb13b6ce48a998508b0fa5e776;
        uint8 v = 27;
        bytes32 _r = 0x64e82c811ee5e912c0f97ac1165c73d593654a6fc434a470452d8bca6ec98424;
        bytes32 _s = 0x5a209fe6efcf6e06ec96620fd968d6331f5e02e5db757ea2a58229c9b3c033ed;
        uint8 _v = 28;

        uint256 amount = 10**18;
        hevm.warp(604411200);
        assertEq(now, 604411200);
        yamV3.permit(cal, del, 0, 604411200 + 1 hours, true, _v, _r, _s);
        assertEq(yamV3.allowance(cal, del),uint(-1));
        assertEq(yamV3.nonces(cal),1);
    }

    function test_FailPermitWithExpiry() public {
        uint nonce = 0;
        uint deadline = 0;
        address cal = 0x29C76e6aD8f28BB1004902578Fb108c507Be341b;
        address del = 0xdd2d5D3f7f1b35b7A0601D6A00DbB7D44Af58479;
        bytes32 r = 0xc7a9f6e53ade2dc3715e69345763b9e6e5734bfe6b40b8ec8e122eb379f07e5b;
        bytes32 s = 0x14cb2f908ca580a74089860a946f56f361d55bdb13b6ce48a998508b0fa5e776;
        uint8 v = 27;
        bytes32 _r = 0x64e82c811ee5e912c0f97ac1165c73d593654a6fc434a470452d8bca6ec98424;
        bytes32 _s = 0x5a209fe6efcf6e06ec96620fd968d6331f5e02e5db757ea2a58229c9b3c033ed;
        uint8 _v = 28;

        uint256 amount = 10**18;
        hevm.warp(604411200);
        hevm.warp(now + 2 hours);
        assertEq(now, 604411200 + 2 hours);
        yamV3.permit(cal, del, 0, 1, true, _v, _r, _s);
    }

    function test_FailReplay() public {
        uint nonce = 0;
        uint deadline = 0;
        address cal = 0x29C76e6aD8f28BB1004902578Fb108c507Be341b;
        address del = 0xdd2d5D3f7f1b35b7A0601D6A00DbB7D44Af58479;
        bytes32 r = 0xc7a9f6e53ade2dc3715e69345763b9e6e5734bfe6b40b8ec8e122eb379f07e5b;
        bytes32 s = 0x14cb2f908ca580a74089860a946f56f361d55bdb13b6ce48a998508b0fa5e776;
        uint8 v = 27;
        bytes32 _r = 0x64e82c811ee5e912c0f97ac1165c73d593654a6fc434a470452d8bca6ec98424;
        bytes32 _s = 0x5a209fe6efcf6e06ec96620fd968d6331f5e02e5db757ea2a58229c9b3c033ed;
        uint8 _v = 28;

        uint256 amount = 10**18;
        yamV3.permit(cal, del, 0, 0, true, v, r, s);
        yamV3.permit(cal, del, 0, 0, true, v, r, s);
    }

    function test_direct_rebase() public {
      yamV3._setRebaser(me);
      assertEq(yamV3.rebaser(), me);

      // positive rebase
      uint256 balance = yamV3.balanceOf(me);
      uint256 underlying = yamV3.balanceOfUnderlying(me);

      uint256 totalSupply = yamV3.rebase(1, 10**17, true);

      uint256 scalingFactor = yamV3.yamsScalingFactor();
      assertEq(scalingFactor, 11*10**17);

      assertEq(totalSupply, balance.mul(scalingFactor).div(BASE));

      assertEq(yamV3.initSupply(), underlying);

      // negative rebase
      /* totalSupply = yamV3.rebase(2, 10**17, false);

      scalingFactor = yamV3.yamsScalingFactor();
      assertEq(scalingFactor, 10**18);

      assertEq(totalSupply, balance.mul(scalingFactor).div(BASE));

      assertEq(yamV3.initSupply(), underlying);

      // zero rebase
      totalSupply = yamV3.rebase(3, 0, false);

      scalingFactor = yamV3.yamsScalingFactor();
      assertEq(scalingFactor, 10**18);

      assertEq(totalSupply, balance.mul(scalingFactor).div(BASE));

      assertEq(yamV3.initSupply(), underlying); */
    }

    function test_setRoles() public {
      yamV3._setRebaser(address(user));
      assertEq(yamV3.rebaser(), address(user));
      yamV3._setMigrator(address(user));
      assertEq(yamV3.migrator(), address(user));
      yamV3._setIncentivizer(address(user));
      assertEq(yamV3.incentivizer(), address(user));
      yamV3._setPendingGov(address(user));
      assertEq(yamV3.pendingGov(), address(user));
      user.doAcceptGov(yamV3);
      assertEq(yamV3.gov(), address(user));
    }

    function test_rescueTokens() public {
        SafeERC20.safeTransfer(IERC20(dai), address(yamV3), 100);

        assertTrue(yamV3.rescueTokens(dai, me, 100));
    }
}
