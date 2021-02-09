// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;
import {
    MonthlyAllowance
} from "../contributor_monthly_payments/MonthlyAllowance.sol";
import {VestingPool} from "../vesting_pool/VestingPool.sol";
import {IERC20} from "../../lib/IERC20.sol";

interface IBasicIssuanceModule {
    function issue(
        address _setToken,
        uint256 _quantity,
        address _to
    ) external;
}

contract SetJoiner {
    address constant SET_TOKEN = 0xD83dfE003E7c42077186D690DD3D24a0c965ca4e;

    IBasicIssuanceModule constant ISSUANCE_MODULE = IBasicIssuanceModule(
        0xd8EF3cACe8b4907117a45B0b125c68560532F94D
    );

    IERC20 YUSD = IERC20(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);

    address constant RESERVES = 0x97990B693835da58A281636296D2Bf02787DEa17;

    function execute() public {
        YUSD.approve(address(ISSUANCE_MODULE), uint256(-1));
        ISSUANCE_MODULE.issue(SET_TOKEN, 810000 * (10**18), RESERVES);
        selfdestruct(address(0x0));
    }
}
