// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Modified from Gnosis (https://github.com/gnosis/gp-v2-contracts/blob/main/src/contracts/libraries/GPv2SafeERC20.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
library SafeTransferLib {
    /*///////////////////////////////////////////////////////////////
                            ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool callStatus;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            callStatus := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(callStatus, "ETH_TRANSFER_FAILED");
    }
}


// A partial ERC20 interface.
interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IERC721 {
  function approve(address to, uint256 tokenId) external;
}

// Minimal setup for curve error codes
contract CurveErrorCodes {
    enum Error {
        OK, // No error
        INVALID_NUMITEMS, // The numItem value is 0
        SPOT_PRICE_OVERFLOW // The updated spot price doesn't fit into 128 bits
    }
}

// Minimal interface for LSSVMPair
interface ILSSVMPair {
    function swapNFTsForToken(
        uint256[] calldata nftIds,
        uint256 minExpectedTokenOutput,
        address payable tokenRecipient,
        bool isRouter,
        address routerCaller
    ) external returns (uint256 outputAmount);

    function getSellNFTQuote(uint256 numNFTs)
        external
        view
        returns (
            CurveErrorCodes.Error error,
            uint256 newSpotPrice,
            uint256 newDelta,
            uint256 outputAmount,
            uint256 protocolFee
        );
}

contract ZeroExRouter2 {

    using SafeTransferLib for address payable;

    function onERC721Received(
        address operator,
        address from,
        uint256 id,
        bytes memory data
    ) public returns (bytes4) {

        (
          address pairAddress, 
          uint256 minOutput,
          address outputToken,
          address swapTarget,
          bytes memory swapTargetData) = abi.decode(data, (address, uint256, address, address, bytes));

        // // Approve the pair for the specific NFT ID
        IERC721(msg.sender).approve(pairAddress, id);

        // Swap the pair for tokens
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        uint256 outputAmount = ILSSVMPair(pairAddress).swapNFTsForToken(
          ids,
          minOutput,
          payable(address(this)),
          false,
          address(0)
        );

        require(outputAmount > minOutput, ":(");

        // Approve the tokens for the 0x target
        IERC20(outputToken).approve(swapTarget, outputAmount);

        // Swap the tokens for ETH
        (bool success, ) = swapTarget.call(swapTargetData);

        // Send ETH to the original caller
        payable(from).safeTransferETH(address(this).balance);

        // Send any excess tokens to the original caller
        uint256 tokenBalance = IERC20(outputToken).balanceOf(address(this));
        if (tokenBalance > 0) {
          IERC20(outputToken).transfer(from, tokenBalance);
        }

        // Return selector
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
