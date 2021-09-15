pragma solidity 0.5.15;

import {VestingPool} from "../../tests/vesting_pool/VestingPool.sol";
import {IERC20} from "../../lib/IERC20.sol";
import {YAMTokenInterface} from "../../token/YAMTokenInterface.sol";

interface IBasicIssuanceModule {
    function redeem(
        IERC20 setToken,
        uint256 amount,
        address to
    ) external;
}

interface SushiBar {
    function enter(uint256 amount) external;
}

interface YVault {
    function deposit(uint256 amount, address recipient)
        external
        returns (uint256);
}

interface IUMAFarming {
    function _approveExit() external ;
    function _approveEnter() external ;
}

interface IIndexStaking {
    function _approveStakingFromReserves(bool isToken0Limited,
        uint256 amount) external;
}

contract Proposal18 {
    address internal constant RESERVES =
        0x97990B693835da58A281636296D2Bf02787DEa17;

    // For wrapping Sushi into xSushi
    IERC20 internal constant SUSHI =
        IERC20(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    IERC20 internal constant XSUSHI =
        IERC20(0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272);

    // For unwrapping yamHOUSE
    IBasicIssuanceModule internal constant ISSUANCE_MODULE =
        IBasicIssuanceModule(0xd8EF3cACe8b4907117a45B0b125c68560532F94D);
    IERC20 internal constant SET_TOKEN =
        IERC20(0xD83dfE003E7c42077186D690DD3D24a0c965ca4e);

    // For LPing DPI/ETH
    IIndexStaking internal constant INDEX_STAKING =
        IIndexStaking(0x205Cc7463267861002b27021C7108Bc230603d0F);

    // For uGAS liquidity move
    IUMAFarming internal constant UGAS_FARMING_JUN =
        IUMAFarming(0xd25b60D3180Ca217FDf1748c86247A81b1aa43d6);
    IUMAFarming internal constant UGAS_FARMING_SEPT =
        IUMAFarming(0x54837096585faB2E45B9a9b0b38B542136d136D5);

    // For uSTONKS liquidity adding
    IUMAFarming internal constant USTONKS_FARMING_SEPT_1 =
        IUMAFarming(0x9789204c43bbc03E9176F2114805B68D0320B31d);
    IUMAFarming internal constant USTONKS_FARMING_SEPT_2 =
        IUMAFarming(0xdb0742bdBd7876344046f0E7Ca8bC769e85Fdd01);

    IUMAFarming internal constant UPUNKS_FARMING_SEPT =
        IUMAFarming(0x0c9D03B5CDa39184f62C7b05e77408C06A963FE6);

    // Sending USDC and WETH to multisig
    address internal constant TREASURY_MULTISIG = 0x744D16d200175d20E6D8e5f405AEfB4EB7A962d1;
    IERC20 internal constant WETH =
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 internal constant USDC =
        IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // For burning the excess YAM
    YAMTokenInterface internal constant YAM =
        YAMTokenInterface(0x0AaCfbeC6a24756c20D41914F2caba817C0d8521);

    // For depositing remaining USDC to yUSDC
    YVault internal constant yUSDC =
        YVault(0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9);

    // Proposal flow, has 2 separate steps
    uint8 currentStep = 0;

    function executeStepOne() public {
        require(currentStep == 0);
        // Transfer SUSHI to here, wrap to xSUSHI, transfer back to reserves
        uint256 SUSHI_TO_WRAP = SUSHI.balanceOf(RESERVES);
        SUSHI.transferFrom(RESERVES, address(this), SUSHI_TO_WRAP);
        SUSHI.approve(address(XSUSHI), SUSHI_TO_WRAP);
        SushiBar(address(XSUSHI)).enter(SUSHI_TO_WRAP);
        XSUSHI.transfer(RESERVES, XSUSHI.balanceOf(address(this)));

        // Transfer yamHOUSE to here, redeem to reserves
        SET_TOKEN.transferFrom(RESERVES, address(this), 810000 * (10**18));
        ISSUANCE_MODULE.redeem(SET_TOKEN, 810000 * (10**18), RESERVES);

        // Approve exiting uGAS June and entering uGAS Sept
        UGAS_FARMING_JUN._approveExit();
        UGAS_FARMING_SEPT._approveEnter();

        // Approve exiting old uSTONKS Sept and entering new uSTONKS Sept
        USTONKS_FARMING_SEPT_1._approveExit();
        USTONKS_FARMING_SEPT_2._approveEnter();

        // Approve entering uPUNKS Sept farming
        UPUNKS_FARMING_SEPT._approveEnter();

        // Approve entering ETH/DPI uniswap v2
        INDEX_STAKING._approveStakingFromReserves(false, 119 * (10**18));

        // Send WETH to multisig - 3 ETH (~$10k)
        WETH.transferFrom(RESERVES, TREASURY_MULTISIG, 3 * (10**18));

        // Send USDC to multisig - 100,000 USDC
        USDC.transferFrom(RESERVES, TREASURY_MULTISIG, 100000 * (10**6));

        // Burn 20b YAM
        YAM.transferFrom(RESERVES, address(this), 20000000000 * (10**18));
        YAM.burn(20000000000 * (10**18));

        // Incremement to next step
        currentStep++;
    }

    function executeStepTwo() public {
        require(currentStep == 1);
        require(msg.sender == 0xEC3281124d4c2FCA8A88e3076C1E7749CfEcb7F2);
        uint256 usdcBalance = USDC.balanceOf(RESERVES);
        USDC.transferFrom(RESERVES, address(this), usdcBalance);
        USDC.approve(address(yUSDC), usdcBalance);
        yUSDC.deposit(usdcBalance, RESERVES);
        currentStep++;
    }
}
