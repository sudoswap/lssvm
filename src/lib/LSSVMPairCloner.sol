// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {ICurve} from "../bonding-curves/ICurve.sol";
import {LSSVMPairFactoryLike} from "../LSSVMPairFactoryLike.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-1167[EIP 1167] is a standard for
 * deploying minimal proxy contracts, also known as "clones".
 *
 * LSSVMPairCloner slightly modifies EIP-1167 by appending immutable parameters
 * used by the deployed LSSVMPair to the minimal proxy bytecode, in order to
 * save gas on reading those parameters.
 */
library LSSVMPairCloner {
    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(
        address implementation,
        LSSVMPairFactoryLike factory,
        ICurve bondingCurve,
        IERC721 nft,
        uint8 poolType
    ) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x3d606a80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(
                add(ptr, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            mstore(add(ptr, 0x37), shl(0x60, factory))
            mstore(add(ptr, 0x4B), shl(0x60, bondingCurve))
            mstore(add(ptr, 0x5F), shl(0x60, nft))
            mstore8(add(ptr, 0x73), poolType)
            instance := create(0, ptr, 0x74)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(
        address implementation,
        LSSVMPairFactoryLike factory,
        ICurve bondingCurve,
        IERC721 nft,
        uint8 poolType,
        bytes32 salt
    ) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x3d606a80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(
                add(ptr, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            mstore(add(ptr, 0x37), shl(0x60, factory))
            mstore(add(ptr, 0x4B), shl(0x60, bondingCurve))
            mstore(add(ptr, 0x5F), shl(0x60, nft))
            mstore8(add(ptr, 0x73), poolType)
            instance := create2(0, ptr, 0x74, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        LSSVMPairFactoryLike factory,
        ICurve bondingCurve,
        IERC721 nft,
        uint8 poolType,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x3d606a80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(
                add(ptr, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            mstore(add(ptr, 0x37), shl(0x60, factory))
            mstore(add(ptr, 0x4b), shl(0x60, bondingCurve))
            mstore(add(ptr, 0x5f), shl(0x60, nft))
            mstore8(add(ptr, 0x73), poolType)
            mstore8(add(ptr, 0x74), 0xff)
            mstore(add(ptr, 0x75), shl(0x60, deployer))
            mstore(add(ptr, 0x89), salt)
            mstore(add(ptr, 0xa9), keccak256(ptr, 0x74))
            predicted := keccak256(add(ptr, 0x74), 0x55)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        LSSVMPairFactoryLike factory,
        ICurve bondingCurve,
        IERC721 nft,
        uint8 poolType,
        bytes32 salt
    ) internal view returns (address predicted) {
        return
            predictDeterministicAddress(
                implementation,
                factory,
                bondingCurve,
                nft,
                poolType,
                salt,
                address(this)
            );
    }
}
