pragma solidity 0.5.15;

import { YAMDelegator } from "../token/YAMDelegator.sol";
import { DSTest } from "../lib/test.sol";
import { IERC20 } from "../lib/IERC20.sol";

interface Hevm {
    function warp(uint) external;
    function roll(uint) external;
    function store(address,bytes32,bytes32) external;
    function load(address,bytes32) external returns (bytes32);
}

contract HEVMHelpers is DSTest {

    event Debug(uint, bytes32);
    event SlotFound(address who, string sig, uint slot);
    event Logger(uint, bytes);

    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint(keccak256('hevm cheat code'))));

    Hevm hevm = Hevm(address(CHEAT_CODE));

    mapping (address => mapping(bytes4 => uint256)) public slots;
    mapping (address => mapping(bytes4 => bool)) public finds;

    function sigs(
        string memory sig
    )
        public
        pure
        returns (bytes4)
    {
        return bytes4(keccak256(bytes(sig)));
    }

    /// @notice find an arbitrary storage slot given a function sig, input data, address of the contract and a value to check against
    // slot complexity:
    //  if flat, will be bytes32(uint256(uint));
    //  if map, will be keccak256(abi.encode(key, uint(slot)));
    //  if deep map, will be keccak256(abi.encode(key1, keccak256(abi.encode(key0, uint(slot)))));
    //  if map struct, will be bytes32(uint256(keccak256(abi.encode(key1, keccak256(abi.encode(key0, uint(slot)))))) + structFieldDepth);
    function find(
        string memory sig, // signature to check agains
        bytes32[] memory ins, // see slot complexity
        address who, // contract
        bytes32 set
    ) public {
        // calldata to test against
        bytes4 fsig = bytes4(keccak256(bytes(sig)));
        bytes memory dat = flatten(ins);
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
            // load slot
            bytes32 prev = hevm.load(who, slot);
            // store
            hevm.store(who, slot, set);
            // call
            (bool pass, bytes memory rdat) = who.staticcall(cald);
            pass; // ssh
            bytes32 fdat = bytesToBytes32(rdat, 0);
            // check if good
            if (fdat == set) {
                slots[who][fsig] = i;
                finds[who][fsig] = true;
                hevm.store(who, slot, prev);
                emit SlotFound(who, sig, i);
                break;
            }
            // reset storage
            hevm.store(who, slot, prev);
        }

        require(finds[who][fsig], "!found");
    }

    /// @notice write to an arbitrary slot given a function signature
    function writ(
        string memory sig, // signature to check agains
        bytes32[] memory ins, // see slot complexity
        uint256 depth, // see slot complexity
        address who, // contract
        bytes32 set // value to set storage as
    ) public {
        bytes4 fsig = sigs(sig);

        require(finds[who][fsig], "!found");
        bytes32 slot;
        if (ins.length > 0) {
            for (uint256 j = 0; j < ins.length; j++) {
                if (j != 0) {
                    slot = keccak256(abi.encode(ins[j], slot));
                } else {
                    slot = keccak256(abi.encode(ins[j], slots[who][fsig]));
                }
            }
        } else {
            // no ins, so should be flat
            slot = bytes32(slots[who][fsig]);
        }
        // add depth -- noop if 0
        slot = bytes32(uint256(slot) + depth);
        // set storage
        hevm.store(who, slot, set);
    }

    function write_flat(address who, string memory sig, uint256 value) public {
        bytes32[] memory ins = new bytes32[](0);
        if (!finds[who][sigs(sig)]) {
            find(
                sig,
                ins,
                who,
                bytes32(uint256(13371337))
            );
        }
        writ(
            sig,
            ins,
            0,
            who,
            bytes32(value)
        );
    }

    function write_flat(address who, string memory sig, address value) public {
        bytes32[] memory ins = new bytes32[](0);
        if (!finds[who][sigs(sig)]) {
            find(
                sig,
                ins,
                who,
                bytes32(uint256(0xaaaCfBec6a24756c20D41914f2CABA817C0d8521))
            );
        }
        writ(
            sig,
            ins,
            0,
            who,
            bytes32(uint256(value))
        );
    }

    function write_map(address who, string memory sig, uint256 key, uint256 value) public {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = bytes32(uint256(key));
        if (!finds[who][sigs(sig)]) {
            find(
                sig,
                keys,
                who,
                bytes32(uint256(13371337))
            );
        }
        writ(
            sig,
            keys,
            0,
            who,
            bytes32(value)
        );
    }

    function write_map(address who, string memory sig, uint256 key, address value) public {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = bytes32(uint256(key));
        if (!finds[who][sigs(sig)]) {
            find(
                sig,
                keys,
                who,
                bytes32(uint256(13371337))
            );
        }
        writ(
            sig,
            keys,
            0,
            who,
            bytes32(uint256(value))
        );
    }


    function write_map(address who, string memory sig, address key, uint256 value) public {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = bytes32(uint256(key));
        if (!finds[who][sigs(sig)]) {
            find(
                sig,
                keys,
                who,
                bytes32(uint256(13371337))
            );
        }
        writ(
            sig,
            keys,
            0,
            who,
            bytes32(value)
        );
    }

    function write_map(address who, string memory sig, address key, address value) public {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = bytes32(uint256(key));
        if (!finds[who][sigs(sig)]) {
            find(
                sig,
                keys,
                who,
                bytes32(uint256(13371337))
            );
        }
        writ(
            sig,
            keys,
            0,
            who,
            bytes32(uint256(value))
        );
    }

    function write_deep_map(address who, string memory sig, bytes32[] memory keys, uint256 value) public {
        if (!finds[who][sigs(sig)]) {
            find(
                sig,
                keys,
                who,
                bytes32(uint256(13371337))
            );
        }
        writ(
            sig,
            keys,
            0,
            who,
            bytes32(value)
        );
    }

    function write_deep_map(address who, string memory sig, bytes32[] memory keys, address value) public {
        if (!finds[who][sigs(sig)]) {
            find(
                sig,
                keys,
                who,
                bytes32(uint256(13371337))
            );
        }
        writ(
            sig,
            keys,
            0,
            who,
            bytes32(uint256(value))
        );
    }

    function write_deep_map_struct(address who, string memory sig, bytes32[] memory keys, uint256 value, uint256 depth) public {
        if (!finds[who][sigs(sig)]) {
            find(
                sig,
                keys,
                who,
                bytes32(uint256(13371337))
            );
        }
        writ(
            sig,
            keys,
            depth,
            who,
            bytes32(value)
        );
    }

    function write_deep_map_struct(address who, string memory sig, bytes32[] memory keys, address value, uint256 depth) public {
        if (!finds[who][sigs(sig)]) {
            find(
                sig,
                keys,
                who,
                bytes32(uint256(13371337))
            );
        }
        writ(
            sig,
            keys,
            depth,
            who,
            bytes32(uint256(value))
        );
    }

    function bytesToBytes32(bytes memory b, uint offset) public pure returns (bytes32) {
        bytes32 out;

        for (uint i = 0; i < 32; i++) {
            out |= bytes32(b[offset + i] & 0xFF) >> (i * 8);
        }
        return out;
    }

    function flatten(bytes32[] memory b) public pure returns (bytes memory)
    {
        bytes memory result = new bytes(b.length * 32);
        for (uint256 i = 0; i < b.length; i++) {
            bytes32 k = b[i];
            assembly {
                mstore(add(result, add(32, mul(32, i))), k)
            }
        }

        return result;
    }

    function addKnownHEVM(address who, bytes4 fsig, uint slot) public {
        slots[who][fsig] = slot;
        finds[who][fsig] = true;
    }

}

interface YAM {
  function fragmentToYam(uint256) external returns (uint256);
  function yamToFragment(uint256) external returns (uint256);
}

contract YAMHelper is HEVMHelpers {

    address yamAddr = address(0x0AaCfbeC6a24756c20D41914F2caba817C0d8521);

    function addKnown(address yam, string memory sig, uint256 slot) public {
        addKnownHEVM(yam, sigs(sig), slot);
    }

    function write_balanceOf(address who, address acct, uint256 value) public {
        if (who == yamAddr) {
            writeBoU(YAMDelegator(address(uint160(yamAddr))), acct, YAMDelegator(address(uint160(yamAddr))).fragmentToYam(value));
        } else {
            uint256 bal = IERC20(who).balanceOf(acct);
            write_map(who, "balanceOf(address)", acct, value);

            uint256 newTS;
            if (bal > value) {
                uint256 negdelta = bal - value;
                newTS = IERC20(who).totalSupply() - negdelta;
            } else {
                uint256 posdelta = value - bal;
                newTS = IERC20(who).totalSupply() + posdelta;
            }

            write_flat(who, "totalSupply()", newTS);
            assertEq(IERC20(who).totalSupply(), newTS);
        }
    }

    function write_balanceOfUnderlying(address who, address acct, uint256 value) public {
        write_map(who, "balanceOfUnderlying(address)", acct, value);
    }

    function writeBoU(YAMDelegator yamV3, address account, uint256 value) public {
        uint256 bal = yamV3.balanceOfUnderlying(account);
        write_map(address(yamV3), "balanceOfUnderlying(address)", account, value);
        // assertEq(yamV3.balanceOfUnderlying(account), value);
        write_last_checkpoint(yamV3, account, value);

        uint256 newIS;
        uint256 newTS;
        if (bal > value) {
            uint256 negdelta = bal - value;
            newIS = yamV3.initSupply() - negdelta;
            newTS = yamV3.yamToFragment(newIS);
        } else {
            uint256 posdelta = value - bal;
            newIS = yamV3.initSupply() + posdelta;
            newTS = yamV3.yamToFragment(newIS);
        }

        write_flat(address(yamV3), "initSupply()", newIS);
        // assertEq(yamV3.initSupply(), newIS);
        write_flat(address(yamV3), "totalSupply()", newTS);
        // assertEq(yamV3.totalSupply(), newTS);
    }

    function getProposal(YAMDelegator yamV3, address account) public {
        writeBoU(yamV3, account, 10**24*51000);
    }

    function getQuorum(YAMDelegator yamV3, address account) public {
        writeBoU(yamV3, account, 10**24*210000);
        bing();
    }

    function becomeGovernor(address who, address account) public {
        write_flat(who, "pendingGov()", account);
    }

    // may or may not work depending on storage layout
    function becomeGovernorDirect(address who, address account) public {
        write_flat(who, "gov()", account);
    }

    function becomeAdmin(address who, address account) public {
        write_flat(who, "admin()", account);
    }

    function manualCheckpoint(YAMDelegator yamV3, address account, uint256 checkpoint, uint256 fromBlock, uint256 votes) public {
        /* Hevm hevm = Hevm(address(CHEAT_CODE)); */
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = bytes32(uint256(account));
        keys[1] = bytes32(uint256(safe32(checkpoint, "")));
        write_deep_map_struct(address(yamV3), "checkpoints(address,uint32)", keys, fromBlock, 0);
        write_deep_map_struct(address(yamV3), "checkpoints(address,uint32)", keys, votes, 1);
    }

    function write_last_checkpoint(YAMDelegator yamV3, address account, uint256 votes) public {
        /* Hevm hevm = Hevm(address(CHEAT_CODE)); */
        uint256 lcp = yamV3.numCheckpoints(account);
        if (lcp > 0) {
          lcp = lcp - 1;
        }
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = bytes32(uint256(account));
        keys[1] = bytes32(uint256(safe32(lcp, "")));
        write_deep_map_struct(address(yamV3), "checkpoints(address,uint32)", keys, votes, 1);
        if (lcp == 0) {
          write_deep_map_struct(address(yamV3), "checkpoints(address,uint32)", keys, block.number - 1, 0);
          write_map(address(yamV3), "numCheckpoints(address)", account, 1);
        }
        (uint32 fromBlock_post, uint256 votes_post ) = yamV3.checkpoints(account, safe32(lcp, ""));
        assertEq(uint256(fromBlock_post), block.number - 1);
        assertEq(votes_post, votes);
    }

    function safe32(uint n, string memory errorMessage) public pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function bing() public {
        /* Hevm hevm = Hevm(address(CHEAT_CODE)); */
        hevm.roll(block.number + 1);
    }

    function bong(uint256 x) public {
        /* Hevm hevm = Hevm(address(CHEAT_CODE)); */
        hevm.roll(block.number + x);
    }

    function ff(uint256 time) public {
        /* Hevm hevm = Hevm(address(CHEAT_CODE)); */
        hevm.warp(block.timestamp + time);
    }
}
