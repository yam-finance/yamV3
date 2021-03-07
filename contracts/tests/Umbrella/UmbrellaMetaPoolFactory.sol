import {CloneFactory} from "../../lib/CloneFactory.sol";
import {UmbrellaMetaPool} from "./UmbrellaMetaPool.sol";
pragma experimental ABIEncoderV2;

contract UmbrellaMetaPoolFactory is CloneFactory {
    address public target;

    constructor(address target_) public {
        target = target_;
    }

    event PoolCreated();

    function createPool(
        UmbrellaMetaPool.Parameters calldata parameters
    ) external returns (UmbrellaMetaPool newPool) {
        newPool = UmbrellaMetaPool(createClone(target));
        newPool.initialize(
            parameters
        );
        return newPool;
    }
}
