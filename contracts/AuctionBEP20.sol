pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AuctionBEP20 {
    using SafeMath for uint256;
    
    IERC20 public bidToken;
    uint256 public minimumBid;
    uint256 public startBlock;
    uint256 public endBlock;
    uint256 public diffBetweenBids = 100; // 2 bid arasındaki min fark BP -- 100 => 1%
    Offer[] public offers;

    enum OfferStatus { CANCELLED, ACTIVE } // her bid active olarak başlamalı. inactive bidler dahil edilmeyecek.

    struct Offer {
        address bidder;
        uint256 bid;
        uint256 time;
        OfferStatus status;
    }

    constructor(IERC20 bt, uint256 mb, uint256 sb, uint256 eb) {
        bidToken = bt;
        minimumBid = mb;
        startBlock = sb;
        endBlock = eb;
    }

    function getHighestBid() internal view returns(uint256){
        uint256 offerLen = offers.length; // 0 ise hiç offer verilmemiş zaten
        if(offerLen == 0) {
            return 0;
        } else { // offer girilmiş ancak son offeri döndüremeyiz belki cancellanmıştır.
            uint256 highestBid = 0;
            for(uint256 i = offerLen -1; i >= 0;i--) { // en son offerdan ilkine doğru döngü yaptım.
                Offer memory offer = offers[i];
                if(offer.status == OfferStatus.ACTIVE) { // eğer offer aktif ise en yükse bidde ondakidir returnla
                    highestBid = offer.bid;
                    break;
                }
            }
            return highestBid;
        }
    }

}