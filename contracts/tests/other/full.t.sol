// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../../lib/SafeMath.sol";
import "../../lib/SafeERC20.sol";
import {DSTest} from "../../lib/test.sol";
import {YAMDelegator} from "../../token/YAMDelegator.sol";
import {YAMDelegate3} from "../../token/YAMDelegate3.sol";
import {Migrator} from "../../migrator/Migrator.sol";
import {YAMReserves2} from "../../reserves/YAMReserves2.sol";
import {YamGovernorAlpha} from "../../governance/YamGovernorAlpha.sol";
import {Timelock} from "../../governance/TimeLock.sol";
import {YamIncentivizerWithVoting} from "../../incentivizers/YamIncentivizerWithVoting.sol";
import "../../lib/UniswapRouterInterface.sol";

interface Hevm {
    function warp(uint256) external;

    function roll(uint256) external;

    function store(
        address,
        bytes32,
        bytes32
    ) external;
}

interface YAMv2 {
    function decimals() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function approve(address, uint256) external returns (bool);
}

interface YYCRV {
    function deposit(uint256 _amount) external;

    function withdraw(uint256 shares) external;
}

contract User {
    function doTransfer(
        YAMDelegator yamV3,
        address to,
        uint256 amount
    ) external {
        yamV3.transfer(to, amount);
    }

    function doRescueTokens(
        YAMDelegator yamV3,
        address token,
        address to,
        uint256 amount
    ) external {
        yamV3.rescueTokens(token, to, amount);
    }

    function doMint(
        YAMDelegator yamV3,
        address to,
        uint256 amount
    ) external {
        yamV3.mint(to, amount);
    }

    function doApprove(
        YAMDelegator yamV3,
        address spender,
        uint256 amount
    ) external {
        yamV3.approve(spender, amount);
    }

    function doTransferFrom(
        YAMDelegator yamV3,
        address from,
        uint256 amount
    ) external {
        yamV3.transferFrom(from, address(this), amount);
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

    function doRescuetokens(
        YAMDelegator yamV3,
        address token,
        address to,
        uint256 amount
    ) external {
        yamV3.rescueTokens(token, to, amount);
    }
}

contract YAMv3FullTest is DSTest {
    using SafeMath for uint256;

    Hevm hevm;
    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE = bytes20(
        uint160(uint256(keccak256("hevm cheat code")))
    );

    address dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    address multiSig = address(0x0114ee2238327A1D12c2CeB42921EFe314CBa6E6);

    address gitcoinGrants = address(0xde21F729137C5Af1b01d73aF1dC21eFfa2B8a0d6);

    address uniFact = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    address yyCRV = address(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);

    address WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    UniRouter2 uniRouter = UniRouter2(
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    );

    address yCRV = address(0xdF5e0e81Dff6FAF3A7e52BA697820c5e32D806A8);

    YAMv2 yamV2;

    // V3
    YAMDelegate3 delegate; // implementation
    YAMDelegator yamV3; // token
    Migrator migration; // migrator
    YamIncentivizerWithVoting incentives; // LP pool incentivizer
    YAMReserves2 reserves; // reserve contract
    YamGovernorAlpha governor; // protocol governor
    Timelock timelock; // governance owner

    User user;

    address me;

    uint256 public constant BASE = 10**18;

    function setupToken() public {
        // Create an implementation
        delegate = new YAMDelegate3();

        // Create delegator
        yamV3 = new YAMDelegator(
            "YAM",
            "YAM",
            18,
            10000 * 10**18, // 10k for multisig rescue funds
            address(delegate),
            ""
        );

        yamV3.transfer(multiSig, 10000 * 10**18);

        assertTrue(yamV3.initSupply() == 10000 * 10**24);
        assertTrue(yamV3.totalSupply() == 10000 * 10**18);
        assertTrue(yamV3.yamsScalingFactor() == BASE);
        assertTrue(yamV3.balanceOf(me) == 0);
        assertTrue(yamV3.balanceOf(multiSig) == 10000 * 10**18);
    }

    function setupTokenWithExtra() public {
        // Create an implementation
        delegate = new YAMDelegate3();

        // Create delegator
        yamV3 = new YAMDelegator(
            "YAM",
            "YAM",
            18,
            210000 * 10**18, // 10k for multisig rescue funds
            address(delegate),
            ""
        );

        yamV3.transfer(multiSig, 10000 * 10**18);

        assertTrue(yamV3.initSupply() == 210000 * 10**24);
        assertTrue(yamV3.totalSupply() == 210000 * 10**18);
        assertTrue(yamV3.yamsScalingFactor() == BASE);
        assertTrue(yamV3.balanceOf(me) == 200000 * 10**18);
        assertTrue(yamV3.balanceOf(multiSig) == 10000 * 10**18);
    }

    function setupMigrator() public {
        // Create a new migration for testing
        migration = new Migrator();

        yamV3._setMigrator(address(migration));
        assert(yamV3.migrator() == address(migration));

        // set v3
        migration.setV3Address(address(yamV3));

        address[] memory delegators = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        delegators[0] = me;
        amounts[0] = 100 * 10**24;

        migration.addDelegatorReward(delegators, amounts, false);

        migration.delegatorRewardsDone();
    }

    function setupReserves() public {
        reserves = new YAMReserves2(yyCRV, address(yamV3));
    }

    function setupGovernance() public {
        timelock = new Timelock();
        address[] memory incentivizers = new address[](0);
        governor = new YamGovernorAlpha(address(timelock), address(yamV3), incentivizers);
    }

    function finalizeGovernance() public {
        yamV3._setPendingGov(address(timelock));
        reserves._setPendingGov(address(timelock));
        timelock.executeTransaction(address(yamV3), 0, "_acceptGov()", "", 0);
        timelock.executeTransaction(
            address(reserves),
            0,
            "_acceptGov()",
            "",
            0
        );

        incentives.setRewardDistribution(address(timelock));
        incentives.transferOwnership(address(timelock));
        timelock.setPendingAdmin(address(governor));
        governor.__acceptAdmin();
        governor.__abdicate();
        assertTrue(yamV3.gov() == address(timelock));
        assertTrue(reserves.gov() == address(timelock));
        assertTrue(incentives.owner() == address(timelock));
        assertTrue(incentives.rewardDistribution() == address(timelock));
        assertTrue(timelock.admin() == address(governor));
        assertTrue(governor.guardian() == address(0));
    }

    function setupIncentivizer() public {
        incentives = new YamIncentivizerWithVoting();
        incentives.setRewardDistribution(me);
        yamV3._setIncentivizer(address(incentives));
        incentives.notifyRewardAmount(0);
        /* assertEq(yamV3.balanceOf(address(incentives)), 925 * 10**2 * 10**18); */
    }

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        // Cuurrent YAM v2 token
        yamV2 = YAMv2(0xAba8cAc6866B83Ae4eec97DD07ED254282f6aD8A);

        me = address(this);
        /* setupToken(); */
        setupTokenWithExtra();
        setupMigrator();
        setupReserves();
        setupGovernance();
        setupIncentivizer();
        finalizeGovernance();
        // User for testing
        user = new User();
    }

    //
    // TESTS
    //

    function test_scenario() public {
        uint256 yam2balance = yamV2.balanceOf(me);

        yamV2.approve(address(migration), uint256(-1));

        // Warp to start of migration
        hevm.warp(migration.startTime());

        // get v3 tokens
        migration.migrate();

        assertEq(
            yamV3.balanceOfUnderlying(me),
            200000 * 10**24 + yam2balance / 2
        );

        createPoolAndStartIncentives();

        transfer_tests();

        init_twap();

        transfer_tests();

        transfer_tests();

        getIncentiveRewards();

        transfer_tests();

        getIncentiveRewards();

        migration.claimVested();

        transfer_tests();
    }

    function propose_reserves_withdraw_with_quorum(address newReserve)
        public
        returns (bytes32)
    {
        assertTrue(
            yamV3.getPriorVotes(me, block.number - 1) >= 200000 * 10**24
        );
        address[] memory targets = new address[](2);
        targets[0] = address(reserves);
        targets[1] = address(newReserve);
        uint256[] memory values = new uint256[](2);
        string[] memory signatures = new string[](2);
        signatures[0] = "migrateReserves(address,address[])";
        signatures[1] = "_acceptGov()";
        bytes[] memory calldatas = new bytes[](3);
        address[] memory tokens = new address[](2);
        tokens[0] = address(yamV3);
        tokens[1] = address(yyCRV);
        calldatas[0] = abi.encode(newReserve, tokens);
        calldatas[1] = abi.encode(newReserve);

            string memory description
         = "test reserves migration and set new reserves";
        governor.propose(targets, values, signatures, calldatas, description);

        uint256 id = governor.latestProposalIds(me);

        YamGovernorAlpha.ProposalState state = governor.state(id);
        assertTrue(state == YamGovernorAlpha.ProposalState.Pending);

        return
            keccak256(
                abi.encode(
                    targets[0],
                    values[0],
                    signatures[0],
                    calldatas[0],
                    now + timelock.delay()
                )
            );
    }

    function vote_pos_latest() public {
        hevm.roll(block.number + 10);
        uint256 id = governor.latestProposalIds(me);
        governor.castVote(id, true);
    }

    function transfer_tests() public {
        /* uint256 scalingFactor = yamV3.yamsScalingFactor(); */

        uint256 amount = 10**18;
        uint256 yamAmount = yamV3.fragmentToYam(amount);

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

        if (amount > other_balance) {
            assertTrue(amount - other_balance <= 1); // may round
        } else {
            assertTrue(other_balance - amount <= 1); // may round
        }

        assertEq(pre_underlying - yamAmount, underlying);

        pre_balance = yamV3.balanceOf(address(user));
        pre_underlying = yamV3.balanceOfUnderlying(address(user));
        user.doTransfer(yamV3, me, pre_balance);
        balance = yamV3.balanceOf(address(user));
        underlying = yamV3.balanceOfUnderlying(address(user));
        other_balance = yamV3.balanceOf(address(me));
        other_underlying = yamV3.balanceOfUnderlying(address(me));
    }

    function getIncentiveRewards() public {
        address yyCRVPool = pairFor(address(yamV3), yyCRV);

        uint256 pre_balance = yamV3.balanceOf(me) +
            yamV3.balanceOf(yyCRVPool) +
            yamV3.balanceOf(address(reserves)) +
            yamV3.balanceOf(address(incentives)) +
            yamV3.balanceOf(multiSig) +
            yamV3.balanceOf(address(user));
        uint256 pre_underlying = yamV3.balanceOfUnderlying(me) +
            yamV3.balanceOfUnderlying(yyCRVPool) +
            yamV3.balanceOfUnderlying(address(reserves)) +
            yamV3.balanceOfUnderlying(address(incentives)) +
            yamV3.balanceOfUnderlying(multiSig) +
            yamV3.balanceOfUnderlying(address(user));

        incentives.getReward();

        uint256 balance = yamV3.balanceOf(me) +
            yamV3.balanceOf(yyCRVPool) +
            yamV3.balanceOf(address(reserves)) +
            yamV3.balanceOf(address(incentives)) +
            yamV3.balanceOf(multiSig) +
            yamV3.balanceOf(address(user));
        uint256 underlying = yamV3.balanceOfUnderlying(me) +
            yamV3.balanceOfUnderlying(yyCRVPool) +
            yamV3.balanceOfUnderlying(address(reserves)) +
            yamV3.balanceOfUnderlying(address(incentives)) +
            yamV3.balanceOfUnderlying(multiSig) +
            yamV3.balanceOfUnderlying(address(user));

        assertTrue(pre_balance <= balance); // may mint
        assertTrue(pre_underlying <= underlying); // may mint

        // there can be rounding errors here
        if (yamV3.totalSupply() > balance) {
            assertTrue(yamV3.totalSupply() - balance < 5);
        } else {
            assertTrue(balance - yamV3.totalSupply() < 5);
        }
    }

    // Helper functions
    function createPoolAndStartIncentives() public {
        createYYCRV_YAMPool();

        IERC20 yyCRVPool = IERC20(pairFor(address(yamV3), yyCRV));

        yyCRVPool.approve(address(incentives), uint256(-1));
        // wait until incentive pool launch
        hevm.warp(incentives.starttime());

        uint256 lp_bal = yyCRVPool.balanceOf(me);

        // lets do some staking
        incentives.stake(lp_bal);

        assertEq(incentives.balanceOf(me), lp_bal);
    }

    function getYYCRV() internal {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = yCRV;
        uniRouter.swapExactETHForTokens.value(10**18)(1, path, me, now + 60);
        uint256 balance = IERC20(yCRV).balanceOf(me);
        uint256 allowance = IERC20(yCRV).allowance(me, yyCRV);
        if (allowance == 0) {
            IERC20(yCRV).approve(yyCRV, uint256(-1));
        }
        YYCRV(yyCRV).deposit(balance);
    }

    function createYAM_ETHPool() internal {
        yamV3.approve(address(uniRouter), uint256(-1));
        uniRouter.addLiquidityETH.value(10**18)(
            address(yamV3),
            100 * 10**18,
            1,
            1,
            me,
            now + 60
        );
    }

    function createYYCRV_YAMPool() internal {
        getYYCRV();
        IERC20(yyCRV).approve(address(uniRouter), uint256(-1));
        yamV3.approve(address(uniRouter), uint256(-1));
        uniRouter.addLiquidity(
            address(yamV3),
            yyCRV,
            IERC20(yyCRV).balanceOf(me) / 2, // equal amounts
            IERC20(yyCRV).balanceOf(me) / 2,
            1,
            1,
            me,
            now + 60
        );
    }

    function push_price_down() internal {
        address[] memory path = new address[](2);
        path[0] = address(yamV3);
        path[1] = yyCRV;
        IERC20(yyCRV).approve(address(uniRouter), uint256(-1));
        yamV3.approve(address(uniRouter), uint256(-1));
        uniRouter.swapExactTokensForTokens(10 * 10**18, 1, path, me, now + 60);
    }

    function push_price_up() internal {
        if (IERC20(yyCRV).balanceOf(me) < 10 * 10**18) {
            getYYCRV();
        }
        address[] memory path = new address[](2);
        path[0] = yyCRV;
        path[1] = address(yamV3);
        IERC20(yyCRV).approve(address(uniRouter), uint256(-1));
        yamV3.approve(address(uniRouter), uint256(-1));
        uniRouter.swapExactTokensForTokens(10 * 10**18, 1, path, me, now + 60);
    }

    function init_twap() internal {
        createYYCRV_YAMPool();
        push_price_up();
        push_price_down();
        hevm.warp(now + 12 hours);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address token0, address token1)
        internal
        view
        returns (address pair)
    {
        pair = address(
            uint256(
                keccak256(
                    abi.encodePacked(
                        hex"ff",
                        uniFact,
                        keccak256(abi.encodePacked(token0, token1)),
                        hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
                    )
                )
            )
        );
    }
}
