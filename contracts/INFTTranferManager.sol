pragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INFTTransferManager {
    function addLegitCaller(address caller) external;
    function transferNFT(IERC721 token, uint256 id, address recv, address oldOwner) external;
    function removeLegitCaller(address caller) external;
    function isLegitCaller(address caller) external view returns(bool);
}