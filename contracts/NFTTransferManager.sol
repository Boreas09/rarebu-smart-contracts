pragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTTransferManager {

    address operator;
    address auctionFactory;
    mapping(address => bool) private callerList; // legit caller adresleri burada olacak.

    constructor(address f) {
        operator = msg.sender;
        auctionFactory = f;
    }

    function addLegitCaller(address caller) public {
        require(msg.sender == operator || msg.sender == auctionFactory, "Only factory and operator can add legit call address.");
        callerList[caller] = true;
    }

    function isLegitCaller(address caller) external view returns(bool) {
        return callerList[caller];
    }


    function transferNFT(IERC721 token, uint256 id, address recv, address oldOwner) external {
        // msg.sender işlemin geldiği kontratın adresi ise doğru
        require(callerList[msg.sender] == true ,"Only legit caller can call this function.");
        bool isApproved = token.isApprovedForAll(oldOwner, recv);
        require(isApproved , "Token is not by owner approved.");
        token.safeTransferFrom(oldOwner, recv, id);
        address newOwner = token.ownerOf(id);
        require(newOwner == recv ,"Problem on nft transfer");
        emit NFTTransferred(address(this), oldOwner, recv, token, id);
    }

    modifier onlyOperator {
        require(msg.sender != address(0), "Sender address zero.");
        require(msg.sender == operator, "Only factory can call.");
        _;
    }


    event NFTTransferred(address indexed manager, address indexed oldOwner, address indexed newOwner, IERC721 token, uint256 id);
}