pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import "./UniHelper.sol";
import {YamSubGoverned} from "../../lib/YamGoverned.sol";
import {TWAPBoundedUGAS1221} from "./TWAPBoundedUGAS1221.sol";
import {SynthMinter} from "./SynthMinter.sol";

contract UGAS1221Farming is TWAPBoundedUGAS1221, UniHelper, YamSubGoverned {
    enum ACTION {
        ENTER,
        EXIT
    }

    constructor(address gov_) public {
        gov = gov_;
    }

    SynthMinter minter =
        SynthMinter(0x7C62e5c39b7b296f4f2244e7EB51bea57ed26e4B);

    bool completed = true;

    ACTION action;

    address internal constant RESERVES =
        address(0x97990B693835da58A281636296D2Bf02787DEa17);

    // ========= MINTING =========

    function _mint(uint256 collateral_amount, uint256 mint_amount) internal {
        WETH.transferFrom(RESERVES, address(this), collateral_amount);
        WETH.approve(address(minter), uint256(-1));

        minter.create(
            SynthMinter.Unsigned(collateral_amount),
            SynthMinter.Unsigned(mint_amount)
        );
    }

    function _repayAndWithdraw() internal {
        UGAS.approve(address(minter), uint256(-1));
        SynthMinter.PositionData memory position = minter.positions(
            address(this)
        );
        uint256 ugasBalance = UGAS.balanceOf(address(this));
        // We might end up with more SEP UGAS than we have debt. These will get sent to the treasury for future redemption
        if (ugasBalance >= position.tokensOutstanding.rawValue) {
            minter.redeem(position.tokensOutstanding);
        } else {
            // We might end up with more debt than we have SEP UGAS. In this case, only redeem MAX(minSponsorTokens, ugasBalance)
            // The extra debt will need to be handled externally, by either waiting until expiry, others sponsoring the debt for later reimbursement, or purchasing the ugas
            minter.redeem(
                SynthMinter.Unsigned(
                    position.tokensOutstanding.rawValue - ugasBalance <=
                        5 * 10**18
                        ? position.tokensOutstanding.rawValue - 5 * 10**18
                        : ugasBalance
                )
            );
        }
    }

    // ========= ENTER ==========

    function enter() public timeBoundsCheck {
        require(action == ACTION.ENTER, "Wrong action");
        require(!completed, "Action completed");
        uint256 ugasReserves;
        uint256 wethReserves;
        (wethReserves,ugasReserves, ) = uniswap_pair.getReserves();
        require(
            withinBounds(wethReserves, ugasReserves),
            "Market rate is outside bounds"
        );
        uint256 wethBalance = 300 * (10**18);
        // Since we are aiming for a CR of 4, we can mint with up to 80% of reserves
        // We mint slightly less so we can be sure there will be enough WETH
        uint256 collateral_amount = (wethBalance * 79) / 100;
        uint256 mint_amount = (collateral_amount * ugasReserves) /
            wethReserves /
            4;
        _mint(collateral_amount, mint_amount);

        _mintLPToken(uniswap_pair, WETH, UGAS, mint_amount, RESERVES);

        completed = true;
    }

    // ========== EXIT  ==========
    function exit() public timeBoundsCheck {
        require(action == ACTION.EXIT);
        require(!completed, "Action completed");
        uint256 ugasReserves;
        uint256 wethReserves;
        (wethReserves,ugasReserves, ) = uniswap_pair.getReserves();
        require(
            withinBounds(wethReserves, ugasReserves),
            "Market rate is outside bounds"
        );

        _burnLPToken(uniswap_pair, address(this));

        _repayAndWithdraw();

        WETH.transfer(RESERVES, WETH.balanceOf(address(this)));
        uint256 ugasBalance = UGAS.balanceOf(address(this));
        if (ugasBalance > 0) {
            UGAS.transfer(RESERVES, ugasBalance);
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