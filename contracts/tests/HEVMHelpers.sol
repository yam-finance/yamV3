pragma solidity 0.5.15;

import { YAMDelegator } from "../token/YAMDelegator.sol";
import { DSTest } from "../lib/test.sol";
import { IERC20 } from "../lib/IERC20.sol";

interface Hevm {
    function warp(uint) external;
    function roll(uint) external;
    function store(address,bytes32,bytes32) external;
    function load(address,bytes32) external returns (bytes32);
    function origin(address) external;
}

contract User {
    function doTransfer(YAMDelegator yamV3, address to, uint256 amount) external {
        yamV3.transfer(to, amount);
    }
}

contract HEVMHelpers is DSTest {
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint(keccak256('hevm cheat code'))));
    mapping (address => mapping(bytes4 => uint256)) public slots;
    mapping (address => mapping(bytes4 => bool)) public finds;

    function findBalanceSlot(address who, address acct) public {
        bytes32[] memory ins = new bytes32[](1);
        ins[0] = bytes32(uint256(acct) << 96);
        find(
            "balanceOf(address)", // signature to check agains
            ins, // see slot complexity
            0, // see slot complexity
            abi.encode(acct), // calldata
            who, // contract
            bytes32(uint256(1337)), // value to set storage as
            abi.encode(1337) // expected return value from call
        );
        /* Hevm hevm = Hevm(address(CHEAT_CODE));
        for (uint256 i = 0; i < 30; i++) {
            bytes32 prev = hevm.load(address(who),
                     keccak256(abi.encode(address(account), uint(i))));

            hevm.store(address(who),
                       keccak256(abi.encode(address(account), uint(i))),
                       bytes32(uint(1337)));

            uint256 bal = IERC20(who).balanceOf(account);
            if (bal == 1337) {
               balanceSlots[who] = i;
               recordedBalanceSlot[who] = true;
               assertEq(balanceSlot, 1337);
               break;
            }
            // reset storage
            hevm.store(address(who),
                       keccak256(abi.encode(address(account), uint(i))),
                       prev);
        } */
    }

    // slot complexity:
    //  if flat, will be bytes32(uint256(uint));
    //  if map, will be keccak256(abi.encode(key, uint(slot)));
    //  if deep map, will be keccak256(abi.encode(key1, keccak256(abi.encode(key0, uint(slot)))));
    //  if map struct, will be bytes32(uint256(keccak256(abi.encode(key1, keccak256(abi.encode(key0, uint(slot)))))) + structDepth);
    function find(
        string memory sig, // signature to check agains
        bytes32[] memory ins, // see slot complexity
        uint256 depth, // see slot complexity
        bytes memory dat, // calldata
        address who, // contract
        bytes32 set, // value to set storage as
        bytes memory ret // expected return value from call
    ) public {
        Hevm hevm = Hevm(address(CHEAT_CODE));
        // calldata to test against
        bytes4 fsig = bytes4(keccak256(bytes(sig)));
        bytes memory cald = abi.encodePacked(fsig, dat);

        // iterate thru slots
        for (uint256 i = 0; i < 30; i++) {
            bytes32 slot;
            if (ins.length > 0) {
                for (uint256 j = 0; j < ins.length; j++) {
                    if (j != 0) {
                        slot = keccak256(abi.encode(ins[j], slot));
                    } else {
                        slot = keccak256(abi.encode(ins[j], uint(i)));
                    }
                }
            } else {
                // no ins, so should be flat
                slot = bytes32(i);
            }
            // add depth -- noop if 0
            slot = bytes32(uint256(slot) + depth);

            // load slot
            bytes32 prev = hevm.load(who, slot);
            // store
            hevm.store(who, slot, set);
            // call
            (bool pass, bytes memory rdat) = who.call(cald);
            // check if good
            if (equals(rdat, ret)) {
                slots[who][fsig] = i;
                finds[who][fsig] = true;
                break;
            }
            // reset storage
            hevm.store(who, slot, prev);
        }
    }

    // Checks if two `bytes memory` variables are equal. This is done using hashing,
    // which is much more gas efficient then comparing each byte individually.
    // Equality means that:
    //  - 'self.length == other.length'
    //  - For 'n' in '[0, self.length)', 'self[n] == other[n]'
    function equals(bytes memory self, bytes memory other)
        internal
        pure
        returns (bool)
    {
        if (self.length != other.length) {
            return false;
        }
        uint addr;
        uint addr2;
        assembly {
            addr := add(self, /*BYTES_HEADER_SIZE*/32)
            addr2 := add(other, /*BYTES_HEADER_SIZE*/32)
        }
        return equals(addr, addr2, self.length);
    }

    // Compares the 'len' bytes starting at address 'addr' in memory with the 'len'
    // bytes starting at 'addr2'.
    // Returns 'true' if the bytes are the same, otherwise 'false'.
    function equals(uint addr, uint addr2, uint len)
        internal
        pure
        returns (bool equal)
    {
        assembly {
            equal := eq(keccak256(addr, len), keccak256(addr2, len))
        }
    }

    function arbitaryWriteBalance(address who, address account, uint256 value) public {
        Hevm hevm = Hevm(address(CHEAT_CODE));
        bytes4 sig = bytes4(keccak256(bytes("balanceOf(address)")));
        if (!finds[who][sig]) {
          findBalanceSlot(who, account);
        }
        bytes32 slot = bytes32(slots[who][sig]);
        hevm.store(who, slot, bytes32(uint(value)));
    }

    function writeBalance(YAMDelegator yamV3, address account, uint256 value) public {
        Hevm hevm = Hevm(address(CHEAT_CODE));
        uint128 bal = yamV3.balanceOfUnderlying(account);
        hevm.store(address(yamV3),
                   keccak256(abi.encode(address(account), uint(10))),
                   bytes32(uint(value)));
        if (bal > value) {
          uint256 negdelta = bal - value;
          uint256 newIS = yamV3.initSupply() - negdelta;
          uint256 newTS = yamV3.yamToFragment(newIS);
          hevm.store(address(yamV3),
                     bytes32(uint(12)),
                     bytes32(newIS));
          assertEq(yamV3.initSupply(), newIS);
          hevm.store(address(yamV3),
                     bytes32(uint(8)),
                     bytes32(newTS));
          assertEq(yamV3.totalSupply(), newTS);
        } else {
          uint256 posdelta = value - bal;
          uint256 newIS = yamV3.initSupply() + posdelta;
          uint256 newTS = yamV3.yamToFragment(newIS);

          hevm.store(address(yamV3),
                     bytes32(uint(12)),
                     bytes32(newIS));
          assertEq(yamV3.initSupply(), newIS);
          hevm.store(address(yamV3),
                     bytes32(uint(8)),
                     bytes32(newTS));
          assertEq(yamV3.totalSupply(), newTS);
        }
    }

    function makeProposalReady(YAMDelegator yamV3, address account, User user) public {
      Hevm hevm = Hevm(address(CHEAT_CODE));
      writeBalance(yamV3, address(user), 10**24*51000);
      user.doTransfer(yamV3, account, yamV3.yamToFragment(10**24*51000)); // forces checkpoint
      hevm.roll(block.number + 1);
    }

    function makeQuorumReady(YAMDelegator yamV3, address account, User user) public {
      Hevm hevm = Hevm(address(CHEAT_CODE));
      writeBalance(yamV3, address(user), 10**24*210000);
      user.doTransfer(yamV3, account, yamV3.yamToFragment(10**24*210000)); // forces checkpoint
      hevm.roll(block.number + 1);
    }

    function manualCheckpoint(YAMDelegator yamV3, address account, uint256 checkpoint, uint256 value) public {
      Hevm hevm = Hevm(address(CHEAT_CODE));
      uint256 slot = 15;
      hevm.store(address(yamV3),
                 bytes32(uint256(
                   keccak256(
                     abi.encode(
                       uint256(safe32(checkpoint, "")),
                       keccak256(
                         abi.encode(account, uint(slot))
                        )
                     )
                   )
                  ) + 1),
                 bytes32(uint(value)));
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }
}
