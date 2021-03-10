pragma solidity 0.5.15;
pragma experimental ABIEncoderV2;

import {CloneFactory} from "../../lib/CloneFactory.sol";
import {UmbrellaMetaPool} from "./UmbrellaMetaPool.sol";

contract UmbrellaMetaPoolFactory is CloneFactory {
    address public target;

    constructor(address target_) public {
        target = target_;
    }

    event PoolCreated(UmbrellaMetaPool pool);

    function createPool(UmbrellaMetaPool.Parameters calldata parameters)
        external
        returns (UmbrellaMetaPool newPool)
    {
        newPool = UmbrellaMetaPool(createClone(target));
        newPool.initialize(parameters);
        emit PoolCreated(newPool);
        return newPool;
    }
}
