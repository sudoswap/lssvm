// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;
import "./Test721.sol";
import "./RoyaltyOverride.sol";

contract Test721BatchMintWithRoyalty is Test721, RoyaltyOverride {
    
    constructor(address recipient, FeeType feeType, uint256 value) 
        Test721() 
        RoyaltyOverride(recipient, feeType, value) 
    { }

    function batchMint(address to, uint256[] calldata ids) public {
        for (uint256 i = 0; i < ids.length; i++) {
            _mint(to, ids[i]);
        }
    }

    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual
        override (ERC721, RoyaltyOverride)
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }

}
