pragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./AuctionBEP20.sol";
import "./INFTTranferManager.sol";

contract AuctionFactory is Ownable {
    using SafeMath for uint256;
    uint256 private auctionFee; // auction sonunda ödenecek olan fee.
    address private operator; // tüm auctionlarda yönetim yetkisi olacak operatör.
    bool private isAuctionsOnline; // auctionları kapatıp açabilmeye yarıyor.
    uint256 public minimumAuctionLength; // auctionun minimum kaç blok süreceği.
    uint256 public maximumAuctionLength; // auction kaç blok sürebilir
    INFTTransferManager private manager;

    mapping(address => mapping(uint256 => address)) public auctionList; // tokenAddr -> tokenId -> auction address
    mapping(IERC20 => bool) public allowedToken;

    constructor(uint256 fee, address op, uint256 length, uint256 maxLength) {
        auctionFee = fee;
        operator = op;
        minimumAuctionLength = length;
        maximumAuctionLength = maxLength;
    }

    // auction oluşturmak için önce yeni kontratı oluşturulım ve bu kontrat adresini alalım.
    function createBEP20Auction(IERC721 tokenAddress, uint256 tokenId, IERC20 bidToken, uint256 minBid, uint256 startBlock, uint256 endBlock) public returns(address) {
        //AuctionBEP20 a = new AuctionBEP20();
        //return address(a);
        require(msg.sender != address(0), "Sender address zero.");
        require(address(tokenAddress) != address(0), "Token address cant be zero.");
        address owner = tokenAddress.ownerOf(tokenId);
        require(owner == msg.sender, "Only token owner can create auction.");
        require(allowedToken[bidToken], "This token is not allowed for auctions.");
        require(endBlock > startBlock, "End block should be higher than start.");
        require(startBlock >= block.number, "Start block cant be early than current.");
        uint256 auctionLen = endBlock.sub(startBlock);
        require(auctionLen >= minimumAuctionLength, "Auction length is too low.");
        require(auctionLen <= maximumAuctionLength, "Auction length is too high.");
        bool isApproved = tokenAddress.isApprovedForAll(msg.sender, address(manager));
        require(isApproved, "Token is not approved for manager.");
        AuctionBEP20 a = new AuctionBEP20(
            tokenAddress,
            tokenId,
            bidToken,
            minBid,
            startBlock,
            endBlock,
            manager,
            operator
        );
        // auction kontratı oluşturduk şimdi managera bu kontratı kaydedelim.

        manager.addLegitCaller(address(a));
        // managera caller kaydedildi.

        auctionList[address(tokenAddress)][tokenId] = address(a);

        return address(a);
    }

    function setTokenAllowed(IERC20 token) public {
        require(msg.sender == operator,"Only operator.");
        require(msg.sender != address(0) , "Sender address zero.");
        require(address(token) != address(0), "Token address zero.");
        allowedToken[token] = true;
    }

    function flipAuctionCreations() public {
        require(msg.sender == operator,"Only operator.");
        require(msg.sender != address(0) , "Sender address zero.");
        isAuctionsOnline = !isAuctionsOnline;
        emit AuctionCreationStateChanged(msg.sender, isAuctionsOnline);
    }

    function setManagerAddress(INFTTransferManager mgr) public onlyOwner {
        manager = mgr;
    }

    function getManagerAddress() public view returns(address){
        return address(manager);
    }


    event AuctionCreationStateChanged(address indexed operator, bool newState);
    event NewTokenAddedToAllowedList(IERC20 indexed token, address indexed operator);
}   