// SPDX-License-Identifier: GPL-3.0-or-later

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

    function doRescueTokens(YAMDelegator yamV3, address token, address to, uint256 amount) external {
        yamV3.rescueTokens(token, to, amount);
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

    function test_delegateView() public {
        yamV3.approve(address(user), uint256(-1));
        uint256 allowance = yamV3.allowance(me, address(user));
        assertEq(allowance, uint256(-1));
    }


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
        uint256 ctr = 0;
        uint256 starting_bal = yamV3.balanceOf(me);

        // rebaser
        yamV3._setRebaser(address(user));
        assertEq(yamV3.rebaser(), address(user));
        user.doMint(yamV3, me, amount);
        ctr++;
        assertEq(yamV3.balanceOf(me), starting_bal + amount*ctr);
        yamV3._setRebaser(address(me));
        assertEq(yamV3.rebaser(), address(me));

        // incentivizer
        yamV3._setIncentivizer(address(user));
        assertEq(yamV3.incentivizer(), address(user));
        user.doMint(yamV3, me, amount);
        ctr++;
        assertEq(yamV3.balanceOf(me), starting_bal + amount*ctr);
        yamV3._setIncentivizer(address(me));
        assertEq(yamV3.incentivizer(), address(me));

        // gov
        yamV3._setPendingGov(address(user));
        user.doAcceptGov(yamV3);
        user.doMint(yamV3, me, amount);
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
        uint256 other_underlying = yamV3.balanceOfUnderlying(address(user));
        assertEq(pre_balance - amount, balance);
        assertEq(other_balance, amount);
        assertEq(other_underlying, yamAmount);
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
        uint256 other_underlying = yamV3.balanceOfUnderlying(address(user));
        assertEq(pre_balance - amount, balance);
        assertEq(other_balance, amount);
        assertEq(other_underlying, yamAmount);
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
        address cal = 0x683A78bA1f6b25E29fbBC9Cd1BFA29A51520De84;
        address del = 0xdd2d5D3f7f1b35b7A0601D6A00DbB7D44Af58479;
        bytes32 r = 0xc80d2a9c3577543ad49872ca4f4604afbd6a132e8ee0e220de00e05325087c50;
        bytes32 s = 0x2663f17ce7c7de6f7009690fc91c72ef44fca99c839524acaa4393639876d1b8;
        uint8 v = 28;
        uint256 deadline = 1699062789;
        uint256 amount = 10000000;
        yamV3.transfer(cal, amount);
        assertEq(yamV3.nonces(cal), 0);
        assertEq(yamV3.allowance(cal, del), 0);
        yamV3.permit(cal, del, amount, deadline, v, r, s);
        assertEq(yamV3.allowance(cal, del), amount);
        assertEq(yamV3.nonces(cal), 1);
    }

    function testFail_PermitAddress0() public {
        address del = 0xdd2d5D3f7f1b35b7A0601D6A00DbB7D44Af58479;
        bytes32 r = 0xc80d2a9c3577543ad49872ca4f4604afbd6a132e8ee0e220de00e05325087c50;
        bytes32 s = 0x2663f17ce7c7de6f7009690fc91c72ef44fca99c839524acaa4393639876d1b8;
        uint8 v = 28;
        uint256 deadline = 1699062789;
        yamV3.permit(address(0), del, 10000000, deadline, v, r, s);
    }

    function testFail_PermitWithExpiry() public {
        address cal = 0x683A78bA1f6b25E29fbBC9Cd1BFA29A51520De84;
        address del = 0xdd2d5D3f7f1b35b7A0601D6A00DbB7D44Af58479;
        bytes32 r = 0xc80d2a9c3577543ad49872ca4f4604afbd6a132e8ee0e220de00e05325087c50;
        bytes32 s = 0x2663f17ce7c7de6f7009690fc91c72ef44fca99c839524acaa4393639876d1b8;
        uint8 v = 28;
        uint256 deadline = 1699062789;
        hevm.warp(1699062789);
        hevm.warp(now + 2 hours);
        yamV3.permit(cal, del, 10000000, deadline, v, r, s);
    }

    function testFail_Replay() public {
        address cal = 0x683A78bA1f6b25E29fbBC9Cd1BFA29A51520De84;
        address del = 0xdd2d5D3f7f1b35b7A0601D6A00DbB7D44Af58479;
        bytes32 r = 0xc80d2a9c3577543ad49872ca4f4604afbd6a132e8ee0e220de00e05325087c50;
        bytes32 s = 0x2663f17ce7c7de6f7009690fc91c72ef44fca99c839524acaa4393639876d1b8;
        uint8 v = 28;
        uint256 deadline = 1699062789;
        yamV3.permit(cal, del, 10000000, deadline, v, r, s);
        yamV3.permit(cal, del, 10000000, deadline, v, r, s);
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
        totalSupply = yamV3.rebase(2, 10**17, false);
    
        scalingFactor = yamV3.yamsScalingFactor();
        assertEq(scalingFactor, 99*10**16);
    
        // rounding error
        assertEq(totalSupply, balance.mul(scalingFactor).div(BASE) + 1);
    
        assertEq(yamV3.initSupply(), underlying);
    
        // zero rebase
        totalSupply = yamV3.rebase(3, 0, false);
    
        scalingFactor = yamV3.yamsScalingFactor();
        assertEq(scalingFactor, 99*10**16);
    
        assertEq(totalSupply, balance.mul(scalingFactor).div(BASE) + 1);
    
        assertEq(yamV3.initSupply(), underlying);
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
        assertEq(yamV3.gov(), me);
        SafeERC20.safeTransfer(IERC20(dai), address(yamV3), 100);
        bool success = yamV3.rescueTokens(dai, me, 100);
        assertTrue(success);
    }

    function testFail_rescueTokens() public {
        assertEq(yamV3.gov(), me);
        SafeERC20.safeTransfer(IERC20(dai), address(yamV3), 100);
        user.doRescueTokens(yamV3, dai, me, 100);
    }
}
