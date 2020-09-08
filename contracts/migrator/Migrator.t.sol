// SPDX-License-Identifier: MIT

pragma solidity 0.5.15;

import "../lib/SafeMath.sol";
import {DSTest} from "../lib/test.sol";
import {YAMDelegator} from "../token/YAMDelegator.sol";
import {YAMDelegate} from "../token/YAMDelegate.sol";
import {Migrator} from "./Migrator.sol";
import "../lib/UniswapRouterInterface.sol";

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
    function doSetV3Address(Migrator migration, address yamV3) external {
        migration.setV3Address(yamV3);
    }

    function doDelegatorRewardsDone(Migrator migration) external {
        migration.delegatorRewardsDone();
    }

    function doMigrate(Migrator migration) external {
        migration.migrate();
    }

    function doClaimVested(Migrator migration) external {
        migration.claimVested();
    }
}

contract YAMMigratorTest is DSTest {
    using SafeMath for uint256;


    UniRouter2 uniRouter = UniRouter2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    Hevm hevm;
    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint(keccak256('hevm cheat code'))));

    address WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    YAMv2 yamV2;

    YAMDelegate delegate;

    YAMDelegator yamV3;

    Migrator migration;

    User user;

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

        // Create a new migration for testing
        migration = new Migrator();

        yamV3._setMigrator(address(migration));

        // User for testing
        user = new User();
    }

    //
    // TESTS
    //

    // Assert setV3Address
    function test_initMigration() public {
        assertTrue(!migration.token_initialized());

        migration.setV3Address(address(yamV3));

        assertTrue(migration.token_initialized());
    }

    // Can only setV3Address once
    function testFail_initMigrationTwice() public {
        assertTrue(!migration.token_initialized());

        migration.setV3Address(address(yamV3));

        // fails (cannot set twice)
        migration.setV3Address(address(yamV3));
    }

    // Unauthorized user cannot initialize Migration
    function testFail_unauthorized_user_setV3address() public {
        assertTrue(!migration.token_initialized());

        // fails
        user.doSetV3Address(migration, address(yamV3));
    }

    // Unauthorized user cannot initialize Migration
    function testFail_unauthorized_user_delegatorRewardsDone() public {
        // fails
        user.doDelegatorRewardsDone(migration);
    }

    // Cannot migrate before migration begins
    function testFail_migrate_before_start() public {
        address me = address(this);
        migration.setV3Address(address(yamV3));

        // Warp to 1 second before beginning of migration
        hevm.warp(migration.startTime() - 1);

        uint yamBalanceInitial = yamV2.balanceOf(me);
        if (yamBalanceInitial > 0) {
            // Will fail because migration hasn't started
            yamV2.approve(address(migration), uint(-1));
            migration.migrate();
        } else {
            // Address had no yams, fails
            assertTrue(false);
        }
    }

    // Cannot migrate before delegator rewards set
    function testFail_migrate_before_reward_set() public {
        address me = address(this);
        migration.setV3Address(address(yamV3));

        // Warp to 1 second before beginning of migration
        hevm.warp(migration.startTime() - 1);

        uint yamBalanceInitial = yamV2.balanceOf(me);
        if (yamBalanceInitial > 0) {
            // Will fail because migration hasn't started
            yamV2.approve(address(migration), uint(-1));
            migration.migrate();
        } else {
            // Address had no yams, fails
            assertTrue(false);
        }
    }


    // Cannot migrate before migration begins
    function testFail_add_delegator_after_set() public {

        address[] memory delegators = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        migration.delegatorRewardsDone();

        // should fail
        migration.addDelegatorReward(
          delegators,
          amounts,
          false
        );
    }

    function test_add_delegator_over_27() public {
        address me = address(this);

        address[] memory delegators = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        delegators[0] = me;
        amounts[0] = 100 * 10**24;

        migration.addDelegatorReward(
          delegators,
          amounts,
          false
        );

        uint256 vesting = migration.delegator_vesting(me);

        assertEq(vesting, amounts[0]);
    }

    function test_add_delegator_under_27() public {
        address me = address(this);

        address[] memory delegators = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        delegators[0] = me;
        amounts[0] = 10 * 10**24;

        migration.addDelegatorReward(
          delegators,
          amounts,
          true
        );

        uint256 vesting = migration.delegator_vesting(me);

        assertEq(vesting, 27*10**24);
    }



    // MAIN TESTs
    // Check first migration works properly
    function test_first_migrate() public {
        address me = address(this);
        migration.setV3Address(address(yamV3));

        migration.delegatorRewardsDone();

        // Warp to start of migration
        hevm.warp(migration.startTime());

        // Initial balances
        uint256 yamV2BalanceStart = yamV2.balanceOf(me);

        uint256 vesting = migration.vesting(me);

        uint256 expectedV3 = yamV2BalanceStart / 2;

        // first migration
        assertEq(vesting, 0);

        if (yamV2BalanceStart > 0) {

            // Approve contract and migrate
            yamV2.approve(address(migration), uint256(-1));
            migration.migrate();

            // Balances after migration
            uint yamV2BalanceEnd = yamV2.balanceOf(me);
            uint yamV3BalanceEnd = yamV3.balanceOfUnderlying(me);
            vesting = migration.vesting(me);

            uint256 claimed = migration.claimed(me);
            assertEq(claimed, 0);

            // Has no more YAMv2
            assertEq(yamV2BalanceEnd, 0);

            // instant mint is as expected
            assertEq(expectedV3, yamV3BalanceEnd);

            // vesting is as expected
            assertEq(expectedV3, vesting);
        } else {
            assertTrue(false);
        }
    }

    function test_first_migrate_with_delegator() public {
        address me = address(this);
        migration.setV3Address(address(yamV3));

        address[] memory delegators = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        delegators[0] = me;
        amounts[0] = 100 * 10**24;

        migration.addDelegatorReward(
          delegators,
          amounts,
          false
        );

        uint256 vesting = migration.delegator_vesting(me);

        assertEq(vesting, amounts[0]);

        migration.delegatorRewardsDone();

        // Warp to start of migration
        hevm.warp(migration.startTime());

        // Initial balances
        uint256 yamV2BalanceStart = yamV2.balanceOf(me);

        vesting = migration.vesting(me);

        uint256 expectedV3 = yamV2BalanceStart / 2;

        // first migration
        assertEq(vesting, 0);

        if (yamV2BalanceStart > 0) {

            // Approve contract and migrate
            yamV2.approve(address(migration), uint256(-1));
            migration.migrate();

            // Balances after migration
            uint yamV2BalanceEnd = yamV2.balanceOf(me);
            uint yamV3BalanceEnd = yamV3.balanceOfUnderlying(me);
            vesting = migration.vesting(me);

            uint256 claimed = migration.claimed(me);
            assertEq(claimed, 0);

            // Has no more YAMv2
            assertEq(yamV2BalanceEnd, 0);

            // instant mint is as expected
            assertEq(expectedV3, yamV3BalanceEnd);

            // vesting is as expected
            assertEq(expectedV3, vesting);
        } else {
            assertTrue(false);
        }
    }

    function test_first_migrate_with_delegator_and_time() public {
        address me = address(this);
        migration.setV3Address(address(yamV3));

        address[] memory delegators = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        delegators[0] = me;
        amounts[0] = 100 * 10**24;

        migration.addDelegatorReward(
          delegators,
          amounts,
          false
        );

        uint256 vesting = migration.delegator_vesting(me);

        assertEq(vesting, amounts[0]);

        migration.delegatorRewardsDone();

        // Warp to start of migration
        hevm.warp(migration.startTime());

        // Initial balances
        uint256 yamV2BalanceStart = yamV2.balanceOf(me);

        vesting = migration.vesting(me);

        uint256 expectedV3 = yamV2BalanceStart / 2;

        // first migration
        assertEq(vesting, 0);

        if (yamV2BalanceStart > 0) {

            // Approve contract and migrate
            yamV2.approve(address(migration), uint256(-1));
            migration.migrate();

            // Balances after migration
            uint yamV2BalanceEnd = yamV2.balanceOf(me);
            uint yamV3BalanceEnd = yamV3.balanceOfUnderlying(me);
            vesting = migration.vesting(me);

            uint256 claimed = migration.claimed(me);
            assertEq(claimed, 0);

            // Has no more YAMv2
            assertEq(yamV2BalanceEnd, 0);

            // instant mint is as expected
            assertEq(expectedV3, yamV3BalanceEnd);

            // vesting is as expected
            assertEq(expectedV3, vesting);
        } else {
            assertTrue(false);
        }

        // warp to half way
        hevm.warp(migration.startTime() + 15 days);


        uint256 vested = migration.vested(me);

        // half way thru, expect vested == yamV2BalanceStart / 2 / 2
        uint256 delegator_perc = (uint256(15 days)).mul(10**18).div(migration.delegatorVestingDuration());
        assertEq(vested, expectedV3 / 2 + amounts[0].mul(delegator_perc).div(10**18));

        migration.claimVested();

        uint yamV3BalanceEnd = yamV3.balanceOfUnderlying(me);

        assertEq(expectedV3 + expectedV3 / 2 + amounts[0].mul(delegator_perc).div(10**18), yamV3BalanceEnd);
    }

    function test_double_migrate() public {
        address me = address(this);
        migration.setV3Address(address(yamV3));

        migration.delegatorRewardsDone();

        // Warp to start of migration
        hevm.warp(migration.startTime());

        // Initial balances
        uint256 yamV2BalanceStart = yamV2.balanceOf(me);

        uint256 vesting = migration.vesting(me);

        uint256 expectedV3 = yamV2BalanceStart / 2;

        // first migration
        assertEq(vesting, 0);

        if (yamV2BalanceStart > 0) {

            // Approve contract and migrate
            yamV2.approve(address(migration), uint256(-1));
            migration.migrate();

            // Balances after migration
            uint yamV2BalanceEnd = yamV2.balanceOf(me);
            uint yamV3BalanceEnd = yamV3.balanceOfUnderlying(me);
            vesting = migration.vesting(me);

            uint256 claimed = migration.claimed(me);
            assertEq(claimed, 0);

            // Has no more YAMv2
            assertEq(yamV2BalanceEnd, 0);

            // instant mint is as expected
            assertEq(expectedV3, yamV3BalanceEnd);

            // vesting is as expected
            assertEq(expectedV3, vesting);
        } else {
            assertTrue(false);
        }

        getYAMv2();
        uint256 yamV2BalanceStart_second = yamV2.balanceOf(me);

        vesting = migration.vesting(me);

        uint256 expectedV3_second = yamV2BalanceStart_second / 2;

        // from first migration
        assertEq(vesting, expectedV3);

        if (yamV2BalanceStart_second > 0) {
            // migrate
            migration.migrate();
            // we expect:
            // v3 balance: 1/2 first migration + 1/2 second migration
            uint yamV3BalanceEnd = yamV3.balanceOfUnderlying(me);
            assertEq(yamV3BalanceEnd, expectedV3 + expectedV3_second);
            // v2 balance to be 0
            uint yamV2BalanceEnd = yamV2.balanceOf(me);
            assertEq(yamV2BalanceEnd, 0);
            // vested to be 1/2 first migration + 1/2 second migration
            vesting = migration.vesting(me);
            assertEq(vesting, expectedV3 + expectedV3_second);
            // claimed to be 0
            uint256 claimed = migration.claimed(me);
            assertEq(claimed, 0);
        } else {
            assertTrue(false);
        }
    }


    function test_double_migrate_with_time() public {
        address me = address(this);
        migration.setV3Address(address(yamV3));

        migration.delegatorRewardsDone();

        // Warp to start of migration
        hevm.warp(migration.startTime());

        // Initial balances
        uint256 yamV2BalanceStart = yamV2.balanceOf(me);

        uint256 vesting = migration.vesting(me);

        uint256 expectedV3 = yamV2BalanceStart / 2;

        // first migration
        assertEq(vesting, 0);

        if (yamV2BalanceStart > 0) {

            // Approve contract and migrate
            yamV2.approve(address(migration), uint256(-1));
            migration.migrate();

            // Balances after migration
            uint yamV2BalanceEnd = yamV2.balanceOf(me);
            uint yamV3BalanceEnd = yamV3.balanceOfUnderlying(me);
            vesting = migration.vesting(me);

            uint256 claimed = migration.claimed(me);
            assertEq(claimed, 0);

            // Has no more YAMv2
            assertEq(yamV2BalanceEnd, 0);

            // instant mint is as expected
            assertEq(expectedV3, yamV3BalanceEnd);

            // vesting is as expected
            assertEq(expectedV3, vesting);
        } else {
            assertTrue(false);
        }

        getYAMv2();
        uint256 yamV2BalanceStart_second = yamV2.balanceOf(me);

        // zoom to half complete
        hevm.warp(now + 15 days);

        vesting = migration.vesting(me);

        uint256 expectedV3_second = yamV2BalanceStart_second / 2;

        // from first migration
        assertEq(vesting, expectedV3);

        if (yamV2BalanceStart_second > 0) {
            // migrate
            migration.migrate();
            // we expect:
            // v3 balance: 1/2 first migration + 1/2 second migration + 1/2 vesting v1, 1/2 vesting v2
            uint yamV3BalanceEnd = yamV3.balanceOfUnderlying(me);
            assertEq(yamV3BalanceEnd, expectedV3 + expectedV3_second + expectedV3 / 2 + expectedV3_second / 2 );
            // v2 balance to be 0
            uint yamV2BalanceEnd = yamV2.balanceOf(me);
            assertEq(yamV2BalanceEnd, 0);
            // vested to be 1/2 first migration + 1/2 second migration
            vesting = migration.vesting(me);
            assertEq(vesting, expectedV3 + expectedV3_second);
            // claimed to be 1/2 vesting
            uint256 claimed = migration.claimed(me);
            assertEq(claimed, vesting / 2);
        } else {
            assertTrue(false);
        }
    }

    function test_vesting_half() public {
        address me = address(this);
        migration.setV3Address(address(yamV3));

        migration.delegatorRewardsDone();

        // Warp to start of migration
        hevm.warp(migration.startTime());

        // Initial balances
        uint256 yamV2BalanceStart = yamV2.balanceOf(me);

        uint256 vesting = migration.vesting(me);

        // first migration
        assertEq(vesting, 0);

        uint256 expectedV3 = yamV2BalanceStart / 2;


        if (yamV2BalanceStart > 0) {

            // Approve contract and migrate
            yamV2.approve(address(migration), uint(-1));
            migration.migrate();

            // Balances after migration
            uint yamV2BalanceEnd = yamV2.balanceOf(me);
            uint yamV3BalanceEnd = yamV3.balanceOfUnderlying(me);
            vesting = migration.vesting(me);

            // Has no more YAMv2
            assertEq(yamV2BalanceEnd, 0);

            // instant mint is as expected
            assertEq(expectedV3, yamV3BalanceEnd);

            // vesting is as expected
            assertEq(expectedV3, vesting);
        } else {
            assertTrue(false);
        }

        // warp to half way
        hevm.warp(migration.startTime() + 15 days);


        uint256 vested = migration.vested(me);

        // half way thru, expect vested == yamV2BalanceStart / 2 / 2
        assertEq(vested, expectedV3 / 2);

        migration.claimVested();

        uint yamV3BalanceEnd = yamV3.balanceOfUnderlying(me);

        assertEq(expectedV3 + expectedV3 / 2, yamV3BalanceEnd);
    }


    function test_vesting_full() public {
        address me = address(this);
        migration.setV3Address(address(yamV3));

        migration.delegatorRewardsDone();

        // Warp to start of migration
        hevm.warp(migration.startTime());

        // Initial balances
        uint256 yamV2BalanceStart = yamV2.balanceOf(me);

        uint256 vesting = migration.vesting(me);

        // first migration
        assertEq(vesting, 0);

        uint256 expectedV3 = yamV2BalanceStart / 2;


        if (yamV2BalanceStart > 0) {

            // Approve contract and migrate
            yamV2.approve(address(migration), uint(-1));
            migration.migrate();

            // Balances after migration
            uint yamV2BalanceEnd = yamV2.balanceOf(me);
            uint yamV3BalanceEnd = yamV3.balanceOfUnderlying(me);
            vesting = migration.vesting(me);

            // Has no more YAMv2
            assertEq(yamV2BalanceEnd, 0);

            // instant mint is as expected
            assertEq(expectedV3, yamV3BalanceEnd);

            // vesting is as expected
            assertEq(expectedV3, vesting);
        } else {
            assertTrue(false);
        }

        // warp to end
        hevm.warp(migration.startTime() + 30 days);


        uint256 vested = migration.vested(me);

        // half way thru, expect vested == yamV2BalanceStart / 2
        assertEq(vested, expectedV3);

        migration.claimVested();

        uint yamV3BalanceEnd = yamV3.balanceOfUnderlying(me);

        // may have rounding errors from divide by 2
        assertEq(yamV3BalanceEnd + 1, yamV2BalanceStart);
    }

    function getYAMv2() internal {
        address me = address(this);
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(yamV2);
        uint256 b = yamV2.balanceOf(me);
        uniRouter.swapExactETHForTokens.value(10**18)(1, path, me, now + 60);
        uint256 a = yamV2.balanceOf(me);
        assertTrue(a > b);
    }
}
