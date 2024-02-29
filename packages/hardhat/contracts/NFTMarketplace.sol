// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721Holder, Ownable {
    uint256 public feePercentage;   // Fee percentage to be set by the marketplace owner
    uint256 private constant PERCENTAGE_BASE = 100;

    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
        bool isSold;
    }

    struct Escrow {
        address buyer;
        uint256 amount;
        bool released;
    }

    mapping(address => mapping(uint256 => Listing)) private listings;
    mapping(address => mapping(uint256 => Escrow)) private escrows;

    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event NFTPriceChanged(address indexed seller, uint256 indexed tokenId, uint256 newPrice);
    event NFTUnlisted(address indexed seller, uint256 indexed tokenId);

    constructor() {
        feePercentage = 2;  // Setting the default fee percentage to 2%
    }

    function listNFT(address nftContract, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");

        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true,
            isSold: false
        });

        emit NFTListed(msg.sender, tokenId, price);
    }

    function buyNFT(address nftContract, uint256 tokenId) external payable {
        Listing storage listing = listings[nftContract][tokenId];
        Escrow storage escrow = escrows[nftContract][tokenId];

        require(listing.isActive, "NFT is not listed for sale");
        require(msg.value >= listing.price, "Insufficient payment");

        escrow.buyer = msg.sender;
        escrow.amount = msg.value;

        emit NFTSold(listing.seller, msg.sender, tokenId, listing.price);
    }

    function confirmReceipt(address nftContract, uint256 tokenId) external {
        Listing storage listing = listings[nftContract][tokenId];
        Escrow storage escrow = escrows[nftContract][tokenId];

        require(msg.sender == escrow.buyer, "Only the buyer can confirm receipt");
        require(!escrow.released, "Funds already released");

        // Transfer the fee to the marketplace owner
        uint256 feeAmount = (listing.price * feePercentage) / PERCENTAGE_BASE;
        uint256 sellerAmount = listing.price - feeAmount;
        payable(owner()).transfer(feeAmount); // Transfer fee to marketplace owner

        // Transfer the remaining amount to the seller
        payable(listing.seller).transfer(sellerAmount);

        // Transfer the NFT from the marketplace contract to the buyer
        IERC721(nftContract).safeTransferFrom(address(this), escrow.buyer, tokenId);

        escrow.released = true;
    }

    function changePrice(address nftContract, uint256 tokenId, uint256 newPrice) external {
        require(newPrice > 0, "Price must be greater than zero");
        require(listings[nftContract][tokenId].seller == msg.sender, "You are not the seller");

        listings[nftContract][tokenId].price = newPrice;

        emit NFTPriceChanged(msg.sender, tokenId, newPrice);
    }

    function unlistNFT(address nftContract, uint256 tokenId) external {
        Listing storage listing = listings[nftContract][tokenId];
        Escrow storage escrow = escrows[nftContract][tokenId];

        require(listing.seller == msg.sender, "You are not the seller");
        require(!escrow.released, "Funds already released");

        delete listings[nftContract][tokenId];

        IERC721(nftContract).safeTransferFrom(address(this), listing.seller, tokenId);

        emit NFTUnlisted(msg.sender, tokenId);
    }

    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage < PERCENTAGE_BASE, "Fee percentage must be less than 100");

        feePercentage = newFeePercentage;
    }

    // Optional features can be added here:
    // 1. Ability to track statistics of the listing and sales of NFT on the marketplace
    // 2. Auction functionality where users can bid and highest bidder wins
    // 3. Rating and review system for buyers and sellers
    // 4. Integration with external payment systems for multiple currency support
}