pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./AuctionBEP20.sol";

contract AuctionFactory is Initializable {
    uint256 private auctionFee; // auction sonunda ödenecek olan fee.
    address private operator; // tüm auctionlarda yönetim yetkisi olacak operatör.
    bool private isAuctionsOnline; // auctionları kapatıp açabilmeye yarıyor.

    function initialize(uint256 fee, address op) public initializer {
        auctionFee = fee;
        operator = op;
    }

    function createAuction() public returns(address) {
        //AuctionBEP20 a = new AuctionBEP20();
        //return address(a);
    }

    function flipAuctionCreations() public {
        require(msg.sender == operator,"Only operator.");
        isAuctionsOnline = !isAuctionsOnline;
        emit AuctionCreationStateChanged(msg.sender, isAuctionsOnline);
    }

    

    event AuctionCreationStateChanged(address indexed operator, bool newState);

}