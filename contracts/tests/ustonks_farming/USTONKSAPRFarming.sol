pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "./UniHelper.sol";
import {YamSubGoverned} from "../index_staking/YamGoverned.sol";
import {TWAPBoundedUSTONKSAPR} from "./TWAPBoundedUSTONKSAPR.sol";
import {SynthMinter} from "./SynthMinter.sol";

interface VAULT {
    function withdraw(uint256 amount) external;

    function balanceOf(address user) external returns (uint256);
}

interface CURVE_WITHDRAWER {
    function remove_liquidity_one_coin(
        uint256 amount,
        int128 coin,
        uint256 min
    ) external;
}

contract USTONKSAPRFarming is TWAPBoundedUSTONKSAPR, UniHelper, YamSubGoverned {
    enum ACTION {ENTER, EXIT}

    constructor(address gov_) public {
        gov = gov_;
    }

    SynthMinter minter =
        SynthMinter(0x4F1424Cef6AcE40c0ae4fc64d74B734f1eAF153C);

    bool completed = true;

    ACTION action;

    address internal constant RESERVES =
        address(0x97990B693835da58A281636296D2Bf02787DEa17);

    VAULT internal constant YUSD =
        VAULT(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);
    CURVE_WITHDRAWER internal constant Y_DEPOSIT =
        CURVE_WITHDRAWER(0xbBC81d23Ea2c3ec7e56D39296F0cbB648873a5d3);
    IERC20 internal constant YCRV =
        IERC20(0xdF5e0e81Dff6FAF3A7e52BA697820c5e32D806A8);

    address internal constant MULTISIG = 0x744D16d200175d20E6D8e5f405AEfB4EB7A962d1;  
    // ========= MINTING =========

    function _mint(uint256 collateral_amount, uint256 mint_amount) internal {
        USDC.approve(address(minter), uint256(-1));

        minter.create(
            SynthMinter.Unsigned(collateral_amount),
            SynthMinter.Unsigned(mint_amount)
        );
    }

    function _repayAndWithdraw() internal {
        USTONKS_APR.approve(address(minter), uint256(-1));
        SynthMinter.PositionData memory position =
            minter.positions(address(this));
        uint256 ustonksBalance = USTONKS_APR.balanceOf(address(this));
        // We might end up with more USTONKS APR than we have debt. These will get sent to the treasury for future redemption
        if (ustonksBalance >= position.tokensOutstanding.rawValue) {
            minter.redeem(position.tokensOutstanding);
        } else {
            // We might end up with more debt than we have USTONKS APR. In this case, only redeem MAX(minSponsorTokens, ustonksBalance)
            // The extra debt will need to be handled externally, by either waiting until expiry, others sponsoring the debt for later reimbursement, or purchasing the ustonks
            minter.redeem(
                SynthMinter.Unsigned(
                    position.tokensOutstanding.rawValue - ustonksBalance <=
                        5 * 10**6
                        ? position.tokensOutstanding.rawValue - 5 * 10**6
                        : ustonksBalance
                )
            );
        }
    }

    // ========= ENTER ==========

    function enter() public timeBoundsCheck {
        require(action == ACTION.ENTER, "Wrong action");
        require(!completed, "Action completed");
        uint256 ustonksReserves;
        uint256 usdcReserves;
        (usdcReserves, ustonksReserves, ) = uniswap_pair.getReserves();
        require(
            withinBounds(usdcReserves, ustonksReserves),
            "Market rate is outside bounds"
        );
        YUSD.withdraw(YUSD.balanceOf(address(this)));
        uint256 ycrvBalance = YCRV.balanceOf(address(this));
        YCRV.approve(address(Y_DEPOSIT), ycrvBalance);
        Y_DEPOSIT.remove_liquidity_one_coin(ycrvBalance, 1, 1);
        uint256 usdcBalance = USDC.balanceOf(address(this));

        uint256 collateral_amount = (usdcBalance * 2) / 3;
        uint256 mint_amount =
            (collateral_amount * ustonksReserves) / usdcReserves / 4;
        _mint(collateral_amount, mint_amount);

        _mintLPToken(uniswap_pair, USDC, USTONKS_APR, mint_amount, RESERVES);

        USDC.transfer(MULTISIG, USDC.balanceOf(address(this)));
        completed = true;
    }

    // ========== EXIT  ==========
    function exit() public timeBoundsCheck {
        require(action == ACTION.EXIT);
        require(!completed, "Action completed");
        uint256 ustonksReserves;
        uint256 usdcReserves;
        (usdcReserves, ustonksReserves, ) = uniswap_pair.getReserves();
        require(
            withinBounds(usdcReserves, ustonksReserves),
            "Market rate is outside bounds"
        );

        _burnLPToken(uniswap_pair, address(this));

        _repayAndWithdraw();

        USDC.transfer(RESERVES, USDC.balanceOf(address(this)));
        uint256 ustonksBalance = USTONKS_APR.balanceOf(address(this));
        if (ustonksBalance > 0) {
            USTONKS_APR.transfer(RESERVES, ustonksBalance);
        }
        completed = true;
    }

    // ========= GOVERNANCE ONLY ACTION APPROVALS =========
    function _approveEnter() public onlyGovOrSubGov {
        completed = false;
        action = ACTION.ENTER;
    }

    function _approveExit() public onlyGovOrSubGov {
        completed = false;
        action = ACTION.EXIT;
    }

    // ========= GOVERNANCE ONLY SAFTEY MEASURES =========

    function _redeem(uint256 debt_to_pay) public onlyGovOrSubGov {
        minter.redeem(SynthMinter.Unsigned(debt_to_pay));
    }

    function _withdrawCollateral(uint256 amount_to_withdraw)
        public
        onlyGovOrSubGov
    {
        minter.withdraw(SynthMinter.Unsigned(amount_to_withdraw));
    }

    function _settleExpired() public onlyGovOrSubGov {
        minter.settleExpired();
    }

    function masterFallback(address target, bytes memory data)
        public
        onlyGovOrSubGov
    {
        target.call.value(0)(data);
    }

    function _getTokenFromHere(address token) public onlyGovOrSubGov {
        IERC20 t = IERC20(token);
        t.transfer(RESERVES, t.balanceOf(address(this)));
    }
}
