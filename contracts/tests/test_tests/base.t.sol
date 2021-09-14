// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../../lib/SafeMath.sol";
import "../../lib/SafeERC20.sol";
import { DSTest } from "../../lib/test.sol";
import { YAMDelegator } from "../../token/YAMDelegator.sol";
import { YAMDelegate3 } from "../../token/YAMDelegate3.sol";
import { Migrator } from "../../migrator/Migrator.sol";
import { YAMReserves2 } from "../../reserves/YAMReserves2.sol";
import { YamGovernorAlpha } from "../../governance/YamGovernorAlpha.sol";
import { Timelock } from "../../governance/TimeLock.sol";
import { YamIncentivizerWithVoting } from "../../incentivizers/YamIncentivizerWithVoting.sol";
import "../../lib/UniswapRouterInterface.sol";
import "../../lib/IUniswapV2Pair.sol";
import { YAMHelper, HEVMHelpers } from "../HEVMHelpers.sol";
import { OTC } from "../OTC/OTC.sol";
import {VestingPool} from "../vesting_pool/VestingPool.sol";
import {MonthlyAllowance} from "../contributor_monthly_payments/MonthlyAllowance.sol";
import {WETH9} from "../../lib/WETH9.sol";
import {IndexStaking2} from "../index_staking/indexStake.sol";

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

contract User {
    function doTransfer(YAMDelegator yamV3, address to, uint256 amount) external {
        yamV3.transfer(to, amount);
    }

    function doStake(YAMHelper yamhelper, address incentivizer, uint256 amount) external {
        YamIncentivizerWithVoting inc = YamIncentivizerWithVoting(incentivizer);
        address lp_token = address(inc.slp());
        yamhelper.write_balanceOf(lp_token, address(this), amount);
        IERC20(lp_token).approve(address(inc), uint(-1));
        inc.stake(amount);
    }

    function doGetReward(address incentivizer) external {
        YamIncentivizerWithVoting inc = YamIncentivizerWithVoting(incentivizer);
        inc.getReward();
    }

    function doDelegate(address can_delegate, address delegatee) external {
        YAMDelegator can_del = YAMDelegator(address(uint160(can_delegate)));
        can_del.delegate(delegatee);
    }
}


interface ExpandedERC20 {
  function decimals() external returns (uint256);
}

contract YAMv3Test is DSTest {
    event Logger(bytes);
    event DebugLogger(string);

    using SafeMath for uint256;


    // --- constants
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint(keccak256('hevm cheat code'))));
    uint256 public constant BASE = 10**18;

    // --- yam ecosystem
    YAMDelegator yamV3 = YAMDelegator(0x0AaCfbeC6a24756c20D41914F2caba817C0d8521);
    YamIncentivizerWithVoting incentivizer = YamIncentivizerWithVoting(0xD67c05523D8ec1c60760Fd017Ef006b9F6e496D0);
    YAMReserves2 reserves = YAMReserves2(0x97990B693835da58A281636296D2Bf02787DEa17);
    Timelock timelock = Timelock(0x8b4f1616751117C38a0f84F9A146cca191ea3EC5); // governance owner
    YamGovernorAlpha public governor = YamGovernorAlpha(0x2DA253835967D6E721C6c077157F9c9742934aeA);
    OTC public otc_onchain = OTC(0x92ab5CCe7Af1605da2681458aE52a0BEc4eCB74C);
    VestingPool public vestingPool = VestingPool(0xDCf613db29E4d0B35e7e15e93BF6cc6315eB0b82);
    MonthlyAllowance public monthlyAllowance = MonthlyAllowance(0x03A882495Bc616D3a1508211312765904Fb062d1);
    IndexStaking2 public indexStaking = IndexStaking2(0x205Cc7463267861002b27021C7108Bc230603d0F);

    // --- uniswap
    UniRouter2 uniRouter = UniRouter2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public constant uniFact = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    // --- sushi
    address public constant sushiFact = address(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);

    // --- tokens
    address public constant yyCRV = address(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);
    address public constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant DPI = address(0x1494CA1F11D487c2bBe4543E90080AeBa4BA3C2b);
    address public constant DAI = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address public constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant YAM_HOUSE = address(0xD83dfE003E7c42077186D690DD3D24a0c965ca4e);
    address public constant SUSHI = address(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    address public constant xSUSHI = address(0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272);
    address public constant yUSDC = address(0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9);
    address public constant USDT = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    // --- weth
    WETH9 weth = WETH9(WETH);
    
    
    // --- other
    address public constant multiSig = address(0x0114ee2238327A1D12c2CeB42921EFe314CBa6E6);
    address public constant gitcoinGrants = address(0xde21F729137C5Af1b01d73aF1dC21eFfa2B8a0d6);

    // --- helpers
    Hevm hevm;
    HEVMHelpers helper;
    YAMHelper yamhelper;
    User user;
    address me;

    function setUpCore() public {
        hevm = Hevm(address(CHEAT_CODE));
        me = address(this);
        user = new User();
        helper = new HEVMHelpers();
        yamhelper = new YAMHelper();
        yamhelper.addKnown(address(yamV3), "pendingGov()", 4);
        yamhelper.addKnown(address(yamV3), "totalSupply()", 8);
        yamhelper.addKnown(address(yamV3), "balanceOfUnderlying(address)", 10);
        yamhelper.addKnown(address(yamV3), "initSupply()", 12);
        yamhelper.addKnown(address(yamV3), "checkpoints(address,uint32)", 15);
        yamhelper.addKnown(address(yamV3), "numCheckpoints(address)", 16);
        // 0 out balance
        yamhelper.writeBoU(yamV3, me, 0);
    }

    // --- helpers

    function expect_revert_with(
        address who,
        string memory sig,
        bytes memory args,
        string memory revert_string
    )
        public
    {
        bytes memory calld = abi.encodePacked(helper.sigs(sig), args);
        (bool success, bytes memory ret) = who.call(calld);
        assertTrue(!success);
        string memory ret_revert_string = abi.decode(slice(5, ret.length, ret), (string));
        assertEq(ret_revert_string, revert_string);
    }

    function expect_revert_with(
        address who,
        string memory sig,
        bytes memory args,
        uint256 value,
        string memory revert_string
    )
        public
    {
        bytes memory calld = abi.encodePacked(helper.sigs(sig), args);
        (bool success, bytes memory ret) = who.call.value(value)(calld);
        assertTrue(!success);
        string memory ret_revert_string = abi.decode(slice(5, ret.length, ret), (string));
        assertEq(ret_revert_string, revert_string);
    }

    function expect_revert_with(
        address who,
        bytes4 sig,
        bytes memory args,
        string memory revert_string
    )
        public
    {
        bytes memory calld = abi.encodePacked(sig, args);
        (bool success, bytes memory ret) = who.call(calld);
        assertTrue(!success);
        string memory ret_revert_string = abi.decode(slice(5, ret.length, ret), (string));
        assertEq(ret_revert_string, revert_string);
    }

    function slice(uint256 begin, uint256 end, bytes memory text) public pure returns (bytes memory) {
       bytes memory a = new bytes(end - begin + 1);
       for(uint i=0 ; i <= end - begin; i++) {
           a[i] = bytes(text)[i + begin - 1];
       }
       return a;
   }

    function joinYYCRV_YAMPool() internal {
        IERC20(yyCRV).approve(address(uniRouter), uint256(-1));
        yamV3.approve(address(uniRouter), uint256(-1));
        address yyCRVPool = pairFor(address(yamV3), yyCRV);
        IUniswapV2Pair(yyCRVPool).sync();
        (uint256 reserves0, uint256 reserves1, ) = IUniswapV2Pair(yyCRVPool).getReserves();
        uint256 quote;
        if (address(yamV3) == IUniswapV2Pair(yyCRVPool).token0()) {
          quote = uniRouter.quote(10**18, reserves1, reserves0);
        } else {
          quote = uniRouter.quote(10**18, reserves0, reserves1);
        }

        assertEq(IERC20(yyCRV).balanceOf(me),  0);
        assertEq(yamV3.balanceOf(me) / 2, 0);

        uniRouter.addLiquidity(
            address(yamV3),
            yyCRV,
            yamV3.balanceOf(me) / 2, // equal amounts
            yamV3.balanceOf(me) / 2 * quote / 10**18,
            1,
            1,
            me,
            now + 60
        );
    }

    function pairFor(
        address tokenA,
        address tokenB
    )
        internal
        pure
        returns (address pair)
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                uniFact,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }

    function pairForSushi(
        address factory,
        address tokenA,
        address tokenB
    )
        internal
        pure
        returns (address pair)
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'e18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303' // init code hash
            ))));
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address, address) {
        require(tokenA != tokenB, 'Base: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Base: ZERO_ADDRESS');
        return (token0, token1);
    }


    function vote_pos_latest() public {
        hevm.roll(block.number + 10);
        YamGovernorAlpha curr_gov = YamGovernorAlpha(timelock.admin());
        uint256 id = curr_gov.latestProposalIds(me);
        curr_gov.castVote(id, true);
    }

    function timelock_accept_gov(address accepting_gov) public {
        if (yamV3.getCurrentVotes(me) < 200000 * 10**24) {
            yamhelper.getQuorum(yamV3, me);
        }
        address[] memory targets = new address[](1);
        targets[0] = accepting_gov;
        uint256[] memory values = new uint256[](1);
        values[0] = 0; // dont send eth
        string[] memory signatures = new string[](1);
        signatures[0] = "_acceptGov()"; //function to call
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        string memory description = "timelock accept gov";
        roll_prop(
          targets,
          values,
          signatures,
          calldatas,
          description
        );
    }

    function roll_prop(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    )
        public
    {
        YamGovernorAlpha gov = YamGovernorAlpha(timelock.admin());
        gov.propose(
            targets,
            values,
            signatures,
            calldatas,
            description
        );

        uint256 id = gov.latestProposalIds(me);

        vote_pos_latest();

        hevm.roll(block.number +  12345);

        YamGovernorAlpha.ProposalState state = gov.state(id);
        assertTrue(state == YamGovernorAlpha.ProposalState.Succeeded);

        gov.queue(id);

        hevm.warp(now + timelock.delay());

        gov.execute(id);
    }

    // set the uniswap price relative to another
    function set_two_hop_uni_price(
        address main_uni_pair,
        address secondary_uni_pair,
        address who,
        uint256 quote_price
    )
        public
    {
        IUniswapV2Pair secondary_pair = IUniswapV2Pair(secondary_uni_pair);
        IUniswapV2Pair pair = IUniswapV2Pair(main_uni_pair);
        (uint256 token0Reserves2, uint256 token1Reserves2, ) = secondary_pair.getReserves();

        address token02 = secondary_pair.token0();
        address token12 = secondary_pair.token1();

        if (token02 == pair.token0() || token02 == pair.token1()) {
            // get quote in terms of token02
            uint256 quote = uniRouter.quote(
                10**ExpandedERC20(token02).decimals(),
                token0Reserves2,
                token1Reserves2
            );
            // get inverse
            quote = quote_price.mul(10**ExpandedERC20(token12).decimals()).div(quote);
            set_uni_price(main_uni_pair, who, quote);
        } else if (token12 == pair.token0() || token12 == pair.token1()) {
            // get quote in terms of token12
            uint256 quote = uniRouter.quote(
                10**ExpandedERC20(token12).decimals(),
                token1Reserves2,
                token0Reserves2
            );
            // get inverse
            quote = quote_price.mul(10**ExpandedERC20(token02).decimals()).div(quote);
            set_uni_price(main_uni_pair, who, quote);
        } else {
            require( false, "!pair_two_hop");
        }
    }

    // set the current uniswap price of a pair
    function set_uni_price(
        address uni_pair,
        address who,
        uint256 quote_price
    )
        public
    {
        // adjusts the price by minimally changing token balances in uniswap pair
        IUniswapV2Pair pair = IUniswapV2Pair(uni_pair);
        (uint256 token0Reserves, uint256 token1Reserves, ) = pair.getReserves();
        uint256 quote;
        if ( pair.token0() == who ) {
            quote = uniRouter.quote(10**ExpandedERC20(who).decimals(), token0Reserves, token1Reserves);
        } else if ( pair.token1() == who ) {
            quote = uniRouter.quote(10**ExpandedERC20(who).decimals(), token1Reserves, token0Reserves);
        } else {
            require( false, "!pair" );
        }

        /* assertEq(quote, quote_price); */
        uint256 offPerc;
        if (quote > quote_price) {
            // price too high, increase reserves by off %
            offPerc = quote.sub(quote_price).mul(BASE).div(quote_price);
            /* assertEq(offPerc, 440); */
            uint256 new_bal = IERC20(who).balanceOf(uni_pair).mul(BASE.add(offPerc)).div(BASE);
            yamhelper.write_balanceOf(who, uni_pair, new_bal);
            pair.sync();
        } else {
            // price too low, decrease reserves by off %
            offPerc = quote_price.sub(quote).mul(BASE).div(quote_price);
            /* assertEq(offPerc, 441); */
            uint256 new_bal = IERC20(who).balanceOf(uni_pair).mul(BASE.sub(offPerc)).div(BASE);
            yamhelper.write_balanceOf(who, uni_pair, new_bal);
            pair.sync();
        }
    }

    function atomicGovCore(address has_gov, string[] memory sigs, bytes32[][] memory ins) public {
        // may or may not be YAMDelegator
        address prevGov = YAMDelegator(address(uint160(has_gov))).gov();

        yamhelper.becomeGovernor(has_gov, address(this));
        YAMDelegator(address(uint160(has_gov)))._acceptGov();

        for (uint256 i = 0; i < sigs.length; i++) {
            bytes4 fsig = bytes4(keccak256(bytes(sigs[i])));
            bytes memory dat = yamhelper.flatten(ins[i]);
            bytes memory cald = abi.encodePacked(fsig, dat);
            (bool success, bytes memory rdat) = has_gov.call(cald);
            success; rdat; // ssh
        }

        yamhelper.becomeGovernor(has_gov, prevGov);
        timelock_accept_gov(has_gov);
    }

    function atomicGov(address has_gov, string memory sig, address acct) public {
        // may or may not be YAMDelegator
        bytes32[][] memory ins = new bytes32[][](1);
        ins[0] = new bytes32[](1);
        ins[0][0] = bytes32(uint256(acct));
        string[] memory sigs = new string[](1);
        sigs[0] = sig;
        atomicGovCore(has_gov, sigs, ins);
    }

    function atomicGov(address has_gov, string memory sig, uint val) public {
        // may or may not be YAMDelegator
        bytes32[][] memory ins = new bytes32[][](1);
        ins[0] = new bytes32[](1);
        ins[0][0] = bytes32(val);
        string[] memory sigs = new string[](1);
        sigs[0] = sig;
        atomicGovCore(has_gov, sigs, ins);
    }



    function increase_liquidity(address uni_pair, uint256 scale) public {
        IUniswapV2Pair pair = IUniswapV2Pair(uni_pair);
        (uint256 token0Reserves, uint256 token1Reserves, ) = pair.getReserves();
        if (pair.token0() == WETH) {
            yamhelper.write_map(pair.token0(), "balanceOf(address)", uni_pair, token0Reserves * scale);
        } else {
            yamhelper.write_balanceOf(pair.token0(), uni_pair, token0Reserves * scale);
        }
        if (pair.token1() == WETH) {
            yamhelper.write_map(pair.token1(), "balanceOf(address)", uni_pair, token1Reserves * scale);
        } else {
            yamhelper.write_balanceOf(pair.token1(), uni_pair, token1Reserves * scale);
        }
        pair.sync();
    }
}
