pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "./UniHelper.sol";
import {YamSubGoverned} from "../../lib/YamGoverned.sol";
import {TWAPBoundedUSTONKSSEPT} from "./TWAPBoundedUSTONKSSEPT.sol";
import {SynthMinter} from "./SynthMinter.sol";

contract USTONKSSEPTFarming is TWAPBoundedUSTONKSSEPT, UniHelper, YamSubGoverned {
    enum ACTION {
        ENTER,
        EXIT
    }

    constructor(address gov_) public {
        gov = gov_;
    }

    SynthMinter minter =
        SynthMinter(0x799c9518Ea434bBdA03d4C0EAa58d644b768d3aB);

    bool completed = true;

    ACTION action;

    address internal constant RESERVES =
        address(0x97990B693835da58A281636296D2Bf02787DEa17);

    // ========= MINTING =========

    function _mint(uint256 collateral_amount, uint256 mint_amount) internal {
        USDC.transferFrom(RESERVES, address(this), collateral_amount);
        USDC.approve(address(minter), uint256(-1));

        minter.create(
            SynthMinter.Unsigned(collateral_amount),
            SynthMinter.Unsigned(mint_amount)
        );
    }

    function _repayAndWithdraw() internal {
        SEPT_USTONKS.approve(address(minter), uint256(-1));
        SynthMinter.PositionData memory position = minter.positions(
            address(this)
        );
        uint256 ustonksBalance = SEPT_USTONKS.balanceOf(address(this));
        // We might end up with more SEPT USTONKSA than we have debt. These will get sent to the treasury for future redemption
        if (ustonksBalance >= position.tokensOutstanding.rawValue) {
            minter.redeem(position.tokensOutstanding);
        } else {
            // We might end up with more debt than we have SEPT USTONKS. In this case, only redeem MAX(minSponsorTokens, ustonksBalance)
            // The extra debt will need to be handled externally, by either waiting until expiry, others sponsoring the debt for later reimbursement, or purchasing the ustonks
            minter.redeem(
                SynthMinter.Unsigned(
                    position.tokensOutstanding.rawValue - ustonksBalance <=
                        1 * (10**6)
                        ? position.tokensOutstanding.rawValue - 1 * (10**6)
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
        uint256 usdcBalance = 1000000 * (10**6);
        // Since we are aiming for a CR of 4, we can mint with up to 80% of reserves
        // We mint slightly less so we can be sure there will be enough USDC
        uint256 collateral_amount = (usdcBalance * 79) / 100;
        uint256 mint_amount = (collateral_amount * ustonksReserves) /
            usdcReserves /
            4;
        _mint(collateral_amount, mint_amount);

        _mintLPToken(uniswap_pair, USDC, SEPT_USTONKS, mint_amount, RESERVES);

        completed = true;
    }

    // ========== EXIT  ==========
    function exit() public timeBoundsCheck {
        require(action == ACTION.EXIT);
        require(!completed, "Action completed");
        uint256 ustonksReserves;
        uint256 usdcReserves;
        (usdcReserves,ustonksReserves, ) = uniswap_pair.getReserves();
        require(
            withinBounds(usdcReserves, ustonksReserves),
            "Market rate is outside bounds"
        );

        _burnLPToken(uniswap_pair, address(this));

        _repayAndWithdraw();

        USDC.transfer(RESERVES, USDC.balanceOf(address(this)));
        uint256 ustonksBalance = SEPT_USTONKS.balanceOf(address(this));
        if (ustonksBalance > 0) {
            SEPT_USTONKS.transfer(RESERVES, ustonksBalance);
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