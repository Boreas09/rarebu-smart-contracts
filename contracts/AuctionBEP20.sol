pragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT


import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AuctionBEP20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public bidToken;
    uint256 public minimumBid;
    uint256 public startBlock;
    uint256 public endBlock;
    uint256 public diffBetweenBids = 500; // 2 bid arasındaki min fark BP -- 100 => 1%
    bool public isAuctionCancelled = false;
    Offer[] public offers;

    mapping(address => uint256) public offerMapping; // userAddr => offerIndex;
    mapping(address => bool) public userOffered; // is user offered.
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

    // bir sonraki verilebilecek minimum teklif görüntüleme fonksiyonu
    function minimumNextBid() public view returns(uint256) {
        uint256 lastBid = getHighestBid(); // minimum bid veya daha yükseği.
        if(lastBid == 0) {
            return minimumBid;
        } else {
            uint256 diff = lastBid.mul(diffBetweenBids).div(10000);
            uint256 nextBid = lastBid.add(diff);
            return nextBid;
        }
    }

    function placeBid(uint256 bid) external auctionLive {
        require(msg.sender != address(0),"Sender address zero.");
        uint256 minNext =  minimumNextBid();
        require(bid >= minNext,"Your bid is too low.");
        address lastBidder = getLastOfferUser();
        require(lastBidder != msg.sender , "You already have last offer."); // zaten son offerı bu kişi vermiş revert et.
        _placebid(bid);
    }

    // teklif verir. Eğer mevcut adresin teklifi varsa ne yapacak ???
    // bu internal fonksiyon işlemleri direk yapacak. Bunu çağıran fonksiyon requireları yapması lazım.
    function _placebid(uint256 bid) internal {
        address bidder = msg.sender;
        bool hasUserOffer = userOffered[bidder];
        if(hasUserOffer) {
            // user offered before. Find latest offer index.
            uint256 offerIndex = offerMapping[bidder];
            // son offeri cancellayalım.
            offers[offerIndex].status = OfferStatus.CANCELLED;
            // son offerin miktarını alalım
            uint256 usersLastBid = offers[offerIndex].bid;
            // şimdi userın son offer miktarından şu an ki offer miktarı arasındaki farkı bulalım.
            uint256 userHasToPay = bid.sub(usersLastBid);
            uint256 netUserPaid = transferBidAmount(userHasToPay, bidder);
            uint256 newBid = netUserPaid.add(usersLastBid);
            Offer memory o = Offer({
                bidder : bidder,
                bid : newBid,
                time : block.timestamp,
                status : OfferStatus.ACTIVE
            });
            offers.push(o);
            uint256 userOfferIndex = offers.length -1;
            offerMapping[bidder] = userOfferIndex;

            emit PlacedBid(bidder, newBid);

        } else {
            // bu ilk offer
            uint256 netBid = transferBidAmount(bid, bidder);
            Offer memory o = Offer({
                bidder : bidder,
                bid : netBid,
                time : block.timestamp,
                status : OfferStatus.ACTIVE
            });
            offers.push(o);
            uint256 userOfferIndex = offers.length -1;
            offerMapping[bidder] = userOfferIndex;
            userOffered[bidder] = true;
            emit PlacedBid(bidder, netBid);
        }
    }

    // verilen teklifi geri çekecek fonksiyon. Offerı Cancelled yapar parasını iade eder.
    function cancelBid() public {}

    // auctionu iptal edip payback verecek fonksiyon. endTime geçilmemiş olmalı.
    function cancelAuction() public auctionLive{}

    // auction aktif mi kontrol edip eğer süresi bittiyse endAuction çalıştıracak fonksiyon.
    function updateAuction() public {}

    // auctionın süresi bittiyse ve offer varsa işlemleri yapacak fonksiyon.
    // if checki ile offer var mı yok mu kontrol edilsin.
    function endAuction() public {

    }

    // tüm requirelar bu fonksiyondan önce kontrol edilmeli.
    function _endauction() internal {

    }

    function transferBidAmount(uint256 amount, address bidder) internal returns(uint256) {
        uint256 allowance = bidToken.allowance(bidder, address(this)); // her auction için approve edilmeli. bu geliştirilebilir.
        require(allowance >= amount, "Allowance is lower than bid.");
        uint256 currBal = bidToken.balanceOf(address(this));
        bidToken.safeTransferFrom(bidder, address(this), amount);
        uint256 newBal = bidToken.balanceOf(address(this));
        uint256 netAmount = newBal.sub(currBal); // eğer transfer fee olan bir token eklenirse net tutar çekilsin.
        return netAmount;
    }

    // en son aktif offerı döndürür.
    function getLastOffer() internal view returns(Offer memory o) {
        uint256 offerLen = offers.length;
        if(offerLen == 0) { // offer yok boş dönmeli.
            return o;
        } else {
            for(uint256 i = offerLen -1; i >= 0; i--) {
                Offer memory offer = offers[i];
                if(offer.status == OfferStatus.ACTIVE) {
                    o = offer;
                    break;
                }
            }
            return o;
        }
    }

    // internal fonksiyon 0 dönerse hesaplamayı ona göre yapma
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
            return minimumBid;
        }
    }

    // eğer son offer yoksa address sıfır dönecek.
    // son aktif offerı veren adresi döndürür.
    function getLastOfferUser() internal view returns(address) {
        uint256 offerLen = offers.length;
        // eğer offer yoksa sıfır olacak bu yüzden kontrol edelim.
        if(offerLen == 0) {
            return address(0); // offer yok geri döndür.
        }
        address lastUser = address(0); // en başta adres sıfır ile başlasın
        for(uint256 i = offerLen -1; i >= 0; i--) { // döngü en sondan başlayacak.
            Offer memory o = offers[i];
            if(o.status == OfferStatus.ACTIVE) {
                lastUser = o.bidder;
                break;
            }
        }
        return lastUser;
    }

    modifier auctionLive {
        uint256 currBlock = block.number;
        require(currBlock < endBlock, "Auction was ended.");
        require(currBlock >= startBlock, "Auction was not started yet.");
        require(isAuctionCancelled == false, "Auction is cancelled.");
        _;
    }

    event PlacedBid(address indexed bidder, uint256 amount);
}