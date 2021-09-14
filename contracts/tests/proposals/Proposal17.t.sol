// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "../../tests/test_tests/base.t.sol";
import {IERC20} from "../../lib/IERC20.sol";
import {Proposal17} from "../../proposals/proposal_round_17/Proposal17.sol";
import {Swapper} from "../../tests/swapper/Swapper.sol";

// Prop for July contributor payment and stream setup
contract Prop17 is YAMv3Test {
    Proposal17 private proposal = Proposal17(0x706F53175D91CF03381e31Df39728c6bac352F2C);
    Swapper private swapper = Swapper(0xB4E5BaFf059C5CE3a0EE7ff8e9f16ca9dd91F1fE);

    function setUp() public {
        setUpCore();
    }

    event TEST(
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        string description
    );

    event TEST_NUM(uint256 used);

    /**
     * Summary:
     * 1. Give Proposal permissions to use VestingPool - updating contributor streams
     * 2. Send YAM to distributor - uPUNK rewards payout
     * 3. Send USDC to distributor - monthly contributor payout
     * 4. Delegate INDEX to Feddas
     **/
    function test_onchain_prop_17() public {
        assertTrue(false);

        address[] memory targets = new address[](6);
        uint256[] memory values = new uint256[](6);
        string[] memory signatures = new string[](6);
        bytes[] memory calldatas = new bytes[](6);

        string
            memory description = "Setup proposl for swapper/vestingPool/indexStaking, whitelist withdrawals for contrib. payments/treasury rebalance, send YAM to multisig, withdraw sushi to reserves";
        // -- Set subgov for vesting pool
        targets[0] = address(vestingPool);
        signatures[0] = "setSubGov(address,bool)";
        calldatas[0] = abi.encode(proposal, true);

        // -- Set subgov for swapper
        targets[1] = address(swapper);
        signatures[1] = "setIsSubGov(address,bool)";
        calldatas[1] = abi.encode(proposal, true);

        // -- Set proposal as sub gov for indexStaking
        targets[2] = address(indexStaking);
        signatures[2] = "setIsSubGov(address,bool)";
        calldatas[2] = abi.encode(address(proposal), true);

        // -- Whitelist proposal to withdraw usdc. whitelist Swapper to withdraw WETH, SUSHI, and DPI
        targets[3] = address(reserves);
        signatures[3] = "whitelistWithdrawals(address[],uint256[],address[])";
        address[] memory whos = new address[](4);
        uint256[] memory amounts = new uint256[](4);

        address[] memory tokens = new address[](4);

        whos[0] = address(proposal);
        amounts[0] = uint256(58250 * (10**6));
        tokens[0] = address(USDC);

        whos[1] = address(swapper);
        amounts[1] = uint256(928 * (10**18));
        tokens[1] = address(DPI);

        whos[2] = address(swapper);
        amounts[2] = uint256(120 * (10**18));
        tokens[2] = address(WETH);

        whos[3] = address(swapper);
        amounts[3] = uint256(33733 * (10**18));
        tokens[3] = address(SUSHI);

        calldatas[3] = abi.encode(whos, amounts, tokens);

        // -- Send YAM to treasury multisig
        targets[4] = address(yamV3);
        signatures[4] = "mint(address,uint256)";
        calldatas[4] = abi.encode(
            address(0x744D16d200175d20E6D8e5f405AEfB4EB7A962d1),
            20000 * (10**24)
        );

        // -- Withdraw xSushi from incentivizer into reserves
        targets[5] = address(incentivizer);
        signatures[5] = "sushiToReserves(uint256)";
        calldatas[5] = abi.encode(uint256(-1));



        //
        yamhelper.getQuorum(yamV3, me);
        yamhelper.bing();

        roll_prop(targets, values, signatures, calldatas, description);

        proposal.execute();

        assertEq(IERC20(USDC).balanceOf(address(proposal)), 0);

        swapper.updateCumulativePrice(0);
        swapper.updateCumulativePrice(1);
        swapper.updateCumulativePrice(2);
        yamhelper.ff(90 minutes);

        // -- Attempt swap

        indexStaking.update_twap();

        indexStaking.getUnderlying();

        swapper.execute(0, 33733 * (10**18), 0);
        swapper.execute(1, 120 * (10**18), 0);
        swapper.execute(2, 100 * (10**18), 0);
        yamhelper.ff(180 minutes);
        swapper.updateCumulativePrice(2);
        yamhelper.ff(90 minutes);
        swapper.execute(2, 100 * (10**18), 0);

    }

}
