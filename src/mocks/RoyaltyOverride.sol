// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./Test721.sol";

abstract contract RoyaltyOverride is IERC2981 {
    using FixedPointMathLib for uint256;

    enum FeeType {
        FLAT,
        PERCENT
    }

    address public royaltyRecipient;
    FeeType public feeType;
    uint256 public value;

    constructor(
        address _royaltyRecipient,
        FeeType _feeType,
        uint256 _value
    ) {
        royaltyRecipient = _royaltyRecipient;
        feeType = _feeType;
        value = _value;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId;
    }

    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        if (feeType == FeeType.FLAT) {
            require(salePrice > value, "salePrice below royaltyAmount");
            return (royaltyRecipient, value);
        } else if (feeType == FeeType.PERCENT) {
            royaltyAmount = salePrice.fmul(value, FixedPointMathLib.WAD);
            require(salePrice > royaltyAmount, "salePrice below royaltyAmount");
            return (royaltyRecipient, royaltyAmount);
        }
        return (address(0), 0);
    }
}
