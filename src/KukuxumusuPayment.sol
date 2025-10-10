// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title KukuxumusuPayment
 * @dev Payment contract for Kukuxumusu NFT marketplace on Base network
 * @notice Handles multi-token payments and auction system for NFT purchases
 */
contract KukuxumusuPayment is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /// @notice Role identifier for auction creators
    bytes32 public constant AUCTION_CREATOR_ROLE = keccak256("AUCTION_CREATOR_ROLE");

    /// @notice Trusted signer address (relayer) for bid value verification
    address public trustedSigner;

    /// @dev Auction structure to track auction details
    struct Auction {
        address nftContract; // Contract address of the NFT collection
        uint256 nftId;
        uint256 startTime;
        uint256 endTime;
        address highestBidder;
        address highestBidToken;
        uint256 highestBid;
        uint256 highestBidValueUSD; // Value of highest bid in USD (with 18 decimals)
        bool finalized;
        uint256 antiSnipingExtension; // Time extension in seconds when bid happens near end
        uint256 antiSnipingTrigger; // Time threshold before end to trigger extension
    }

    /// @dev Bid structure to track individual bids
    struct Bid {
        address bidder;
        address token;
        uint256 amount;
        uint256 valueInUSD; // Value in USD (with 18 decimals)
        uint256 timestamp;
    }

    /// @notice Treasury wallet that receives payments
    address public treasury;

    /// @notice Mapping of NFT contract and ID to token address to price
    mapping(address => mapping(uint256 => mapping(address => uint256))) public prices;

    /// @notice Mapping of token addresses that are allowed for payments
    mapping(address => bool) public allowedPaymentTokens;

    /// @notice Mapping of NFT contract addresses that are allowed for auctions
    mapping(address => bool) public allowedNFTContracts;

    /// @notice Mapping of auction ID to Auction struct
    mapping(uint256 => Auction) public auctions;

    /// @notice Mapping of auction ID to allowed payment tokens for that auction
    mapping(uint256 => mapping(address => bool)) public auctionAllowedTokens;

    /// @notice Mapping of auction ID to minimum prices per token
    mapping(uint256 => mapping(address => uint256)) public auctionMinPrices;

    /// @notice Mapping of auction ID to discount percentages per token (0-100)
    mapping(uint256 => mapping(address => uint256)) public auctionDiscounts;

    /// @notice Mapping of auction ID to array of bids
    mapping(uint256 => Bid[]) public auctionBids;

    /// @notice Mapping to track pending refunds for bidders (pull pattern)
    mapping(address => mapping(address => uint256)) public pendingRefunds;

    /// @notice Counter for auction IDs
    uint256 public auctionCounter;

    /// @dev Native ETH address representation
    address public constant NATIVE_ETH = address(0);

    // Events
    event PaymentReceived(
        address indexed buyer,
        uint256 indexed nftId,
        address token,
        uint256 amount,
        uint256 timestamp
    );

    event DirectPurchase(
        address indexed buyer,
        uint256 indexed nftId,
        address token,
        uint256 amount
    );

    event AuctionCreated(
        uint256 indexed auctionId,
        uint256 indexed nftId,
        uint256 startTime,
        uint256 endTime,
        address[] allowedTokens
    );

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        address token,
        uint256 amount,
        uint256 valueInUSD,
        uint256 timestamp
    );

    event AuctionWon(
        uint256 indexed auctionId,
        address indexed winner,
        address indexed nftContract,
        uint256 nftId,
        address token,
        uint256 finalAmount,
        uint256 valueInUSD
    );

    event AuctionFinalized(uint256 indexed auctionId, bool hasWinner);

    event PriceSet(address indexed nftContract, uint256 indexed nftId, address indexed token, uint256 price);

    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    event PaymentTokenUpdated(address indexed token, bool allowed);

    event NFTContractUpdated(address indexed nftContract, bool allowed);

    event RefundProcessed(address indexed bidder, address indexed token, uint256 amount);

    event AuctionExtended(uint256 indexed auctionId, uint256 newEndTime);

    event TrustedSignerUpdated(address indexed oldSigner, address indexed newSigner);

    /**
     * @dev Constructor to initialize the contract
     * @param _treasury Address of the treasury wallet
     * @param initialAdmin Address of the initial admin
     * @param _trustedSigner Address of the trusted signer for bid verification
     */
    constructor(address _treasury, address initialAdmin, address _trustedSigner) {
        require(_treasury != address(0), "Invalid treasury address");
        require(initialAdmin != address(0), "Invalid admin address");
        require(_trustedSigner != address(0), "Invalid trusted signer address");

        treasury = _treasury;
        trustedSigner = _trustedSigner;

        // Grant the DEFAULT_ADMIN_ROLE to the initial admin
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);

        // Grant the AUCTION_CREATOR_ROLE to the initial admin
        _grantRole(AUCTION_CREATOR_ROLE, initialAdmin);
    }

    /**
     * @notice Set the price for an NFT in a specific token
     * @param nftContract The NFT contract address
     * @param nftId The ID of the NFT
     * @param token The payment token address (use address(0) for ETH)
     * @param price The price in the specified token
     */
    function setPrice(address nftContract, uint256 nftId, address token, uint256 price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(nftContract != address(0), "Invalid NFT contract address");
        require(price > 0, "Price must be greater than 0");
        prices[nftContract][nftId][token] = price;
        emit PriceSet(nftContract, nftId, token, price);
    }

    /**
     * @notice Update the treasury wallet address
     * @param _treasury New treasury address
     */
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Invalid treasury address");
        address oldTreasury = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(oldTreasury, _treasury);
    }

    /**
     * @notice Add or remove a token from the allowed payment tokens list
     * @param token Token address to update
     * @param allowed Whether the token is allowed or not
     */
    function setAllowedPaymentToken(address token, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allowedPaymentTokens[token] = allowed;
        emit PaymentTokenUpdated(token, allowed);
    }

    /**
     * @notice Add or remove an NFT contract from the allowed contracts list
     * @param nftContract NFT contract address to update
     * @param allowed Whether the contract is allowed or not
     */
    function setAllowedNFTContract(address nftContract, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(nftContract != address(0), "Invalid NFT contract address");
        allowedNFTContracts[nftContract] = allowed;
        emit NFTContractUpdated(nftContract, allowed);
    }

    /**
     * @notice Update the trusted signer address
     * @param _trustedSigner New trusted signer address
     */
    function setTrustedSigner(address _trustedSigner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_trustedSigner != address(0), "Invalid trusted signer address");
        address oldSigner = trustedSigner;
        trustedSigner = _trustedSigner;
        emit TrustedSignerUpdated(oldSigner, _trustedSigner);
    }

    /**
     * @notice Perform a direct purchase of an NFT
     * @param nftContract The NFT contract address
     * @param nftId The ID of the NFT to purchase
     * @param paymentToken The token to pay with (address(0) for ETH)
     * @param amount The amount to pay
     */
    function directPurchase(
        address nftContract,
        uint256 nftId,
        address paymentToken,
        uint256 amount
    ) external payable nonReentrant whenNotPaused {
        require(nftContract != address(0), "Invalid NFT contract address");
        require(allowedNFTContracts[nftContract], "NFT contract not allowed");
        require(allowedPaymentTokens[paymentToken], "Payment token not allowed");

        uint256 expectedPrice = prices[nftContract][nftId][paymentToken];
        require(expectedPrice > 0, "NFT not available for purchase with this token");
        require(amount == expectedPrice, "Incorrect payment amount");

        if (paymentToken == NATIVE_ETH) {
            require(msg.value == amount, "Incorrect ETH amount sent");
            // Transfer ETH to treasury
            (bool success, ) = treasury.call{value: amount}("");
            require(success, "ETH transfer to treasury failed");
        } else {
            require(msg.value == 0, "ETH not expected for ERC20 payment");
            // Transfer ERC20 tokens to treasury
            IERC20(paymentToken).safeTransferFrom(msg.sender, treasury, amount);
        }

        emit PaymentReceived(msg.sender, nftId, paymentToken, amount, block.timestamp);
        emit DirectPurchase(msg.sender, nftId, paymentToken, amount);
    }

    /**
     * @notice Create a new auction for an NFT
     * @param nftContract The NFT contract address
     * @param nftId The ID of the NFT to auction
     * @param startTime When the auction starts (Unix timestamp, 0 for immediate start)
     * @param duration Duration of the auction in seconds
     * @param allowedTokens Array of tokens allowed for bidding
     * @param minPrices Minimum prices for each allowed token
     * @param discounts Discount percentages for each token (0-100)
     * @param antiSnipingExtension Time extension in seconds when bid happens near end
     * @param antiSnipingTrigger Time threshold before end to trigger extension
     */
    function createAuction(
        address nftContract,
        uint256 nftId,
        uint256 startTime,
        uint256 duration,
        address[] calldata allowedTokens,
        uint256[] calldata minPrices,
        uint256[] calldata discounts,
        uint256 antiSnipingExtension,
        uint256 antiSnipingTrigger
    ) external onlyRole(AUCTION_CREATOR_ROLE) whenNotPaused {
        require(nftContract != address(0), "Invalid NFT contract address");
        require(allowedNFTContracts[nftContract], "NFT contract not allowed");
        require(duration > 0, "Duration must be greater than 0");
        require(allowedTokens.length > 0, "At least one token must be allowed");
        require(allowedTokens.length == minPrices.length, "Tokens and prices length mismatch");
        require(allowedTokens.length == discounts.length, "Tokens and discounts length mismatch");

        // If startTime is 0, start immediately
        if (startTime == 0) {
            startTime = block.timestamp;
        } else {
            require(startTime >= block.timestamp, "Start time must be in the future or 0 for immediate start");
        }

        uint256 auctionId = auctionCounter++;
        uint256 endTime = startTime + duration;

        auctions[auctionId] = Auction({
            nftContract: nftContract,
            nftId: nftId,
            startTime: startTime,
            endTime: endTime,
            highestBidder: address(0),
            highestBidToken: address(0),
            highestBid: 0,
            highestBidValueUSD: 0,
            finalized: false,
            antiSnipingExtension: antiSnipingExtension,
            antiSnipingTrigger: antiSnipingTrigger
        });

        // Set allowed tokens, minimum prices, and discounts for this auction
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            require(minPrices[i] > 0, "Min price must be greater than 0");
            require(discounts[i] <= 100, "Discount must be <= 100");
            auctionAllowedTokens[auctionId][allowedTokens[i]] = true;
            auctionMinPrices[auctionId][allowedTokens[i]] = minPrices[i];
            auctionDiscounts[auctionId][allowedTokens[i]] = discounts[i];
        }

        emit AuctionCreated(auctionId, nftId, startTime, endTime, allowedTokens);
    }

    /**
     * @notice Place a bid on an auction
     * @param auctionId The ID of the auction
     * @param paymentToken The token to bid with
     * @param amount The bid amount in tokens
     * @param valueInUSD The USD value of the bid (with 18 decimals)
     * @param signature Signature from trusted signer verifying the conversion
     */
    function placeBid(
        uint256 auctionId,
        address paymentToken,
        uint256 amount,
        uint256 valueInUSD,
        bytes calldata signature
    ) external payable nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];

        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(!auction.finalized, "Auction already finalized");
        require(auctionAllowedTokens[auctionId][paymentToken], "Token not allowed for this auction");

        uint256 minPrice = auctionMinPrices[auctionId][paymentToken];
        require(amount >= minPrice, "Bid below minimum price");

        // Verify signature from trusted signer
        bytes32 messageHash = keccak256(abi.encodePacked(auctionId, msg.sender, paymentToken, amount, valueInUSD));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address recoveredSigner = ethSignedMessageHash.recover(signature);
        require(recoveredSigner == trustedSigner, "Invalid signature");

        // Compare bids by their USD value
        require(valueInUSD > auction.highestBidValueUSD, "Bid must be higher than current highest bid in USD value");

        // Handle payment
        if (paymentToken == NATIVE_ETH) {
            require(msg.value == amount, "Incorrect ETH amount sent");
        } else {
            require(msg.value == 0, "ETH not expected for ERC20 payment");
            IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);
        }

        // If there was a previous highest bidder, add their bid to pending refunds
        if (auction.highestBidder != address(0)) {
            pendingRefunds[auction.highestBidder][auction.highestBidToken] += auction.highestBid;
        }

        // Update highest bid
        auction.highestBidder = msg.sender;
        auction.highestBidToken = paymentToken;
        auction.highestBid = amount;
        auction.highestBidValueUSD = valueInUSD;

        // Record the bid
        auctionBids[auctionId].push(
            Bid({
                bidder: msg.sender,
                token: paymentToken,
                amount: amount,
                valueInUSD: valueInUSD,
                timestamp: block.timestamp
            })
        );

        // Anti-sniping: extend auction if bid placed near the end
        if (auction.antiSnipingExtension > 0 && auction.antiSnipingTrigger > 0) {
            uint256 timeRemaining = auction.endTime - block.timestamp;
            if (timeRemaining < auction.antiSnipingTrigger) {
                auction.endTime += auction.antiSnipingExtension;
                emit AuctionExtended(auctionId, auction.endTime);
            }
        }

        emit BidPlaced(auctionId, msg.sender, paymentToken, amount, valueInUSD, block.timestamp);
    }

    /**
     * @notice Finalize an auction and transfer winning bid to treasury
     * @param auctionId The ID of the auction to finalize
     */
    function finalizeAuction(uint256 auctionId) external nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];

        require(block.timestamp >= auction.endTime, "Auction not ended yet");
        require(!auction.finalized, "Auction already finalized");

        auction.finalized = true;

        if (auction.highestBidder != address(0)) {
            // Calculate discount and final amount
            uint256 discount = auctionDiscounts[auctionId][auction.highestBidToken];
            uint256 finalAmount = auction.highestBid;

            if (discount > 0) {
                // Apply discount: finalAmount = highestBid * (100 - discount) / 100
                finalAmount = (auction.highestBid * (100 - discount)) / 100;

                // Refund the discount amount to the winner
                uint256 refundAmount = auction.highestBid - finalAmount;
                if (refundAmount > 0) {
                    pendingRefunds[auction.highestBidder][auction.highestBidToken] += refundAmount;
                }
            }

            // Transfer final amount (after discount) to treasury
            if (auction.highestBidToken == NATIVE_ETH) {
                (bool success, ) = treasury.call{value: finalAmount}("");
                require(success, "ETH transfer to treasury failed");
            } else {
                IERC20(auction.highestBidToken).safeTransfer(treasury, finalAmount);
            }

            emit AuctionWon(
                auctionId,
                auction.highestBidder,
                auction.nftContract,
                auction.nftId,
                auction.highestBidToken,
                finalAmount,
                auction.highestBidValueUSD
            );
        }

        emit AuctionFinalized(auctionId, auction.highestBidder != address(0));
    }

    /**
     * @notice Withdraw pending refunds (pull pattern for losing bidders)
     * @param token The token to withdraw
     */
    function withdrawRefund(address token) external nonReentrant {
        uint256 amount = pendingRefunds[msg.sender][token];
        require(amount > 0, "No refund available");

        pendingRefunds[msg.sender][token] = 0;

        if (token == NATIVE_ETH) {
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "ETH refund transfer failed");
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        emit RefundProcessed(msg.sender, token, amount);
    }

    /**
     * @notice Get pending refund for a user and token
     * @param user The user address
     * @param token The token address
     * @return The pending refund amount
     */
    function getPendingRefund(address user, address token) external view returns (uint256) {
        return pendingRefunds[user][token];
    }

    /**
     * @notice Get all bids for an auction
     * @param auctionId The auction ID
     * @return Array of bids
     */
    function getAuctionBids(uint256 auctionId) external view returns (Bid[] memory) {
        return auctionBids[auctionId];
    }

    /**
     * @notice Withdraw funds from contract (emergency/admin function)
     * @param token Token address to withdraw (address(0) for ETH)
     * @param amount Amount to withdraw
     */
    function withdraw(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount > 0, "Amount must be greater than 0");

        if (token == NATIVE_ETH) {
            require(address(this).balance >= amount, "Insufficient ETH balance");
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "ETH withdrawal failed");
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }
    }

    /**
     * @notice Pause the contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Check if a token is allowed for a specific auction
     * @param auctionId The auction ID
     * @param token The token address
     * @return Whether the token is allowed
     */
    function isTokenAllowedForAuction(uint256 auctionId, address token) external view returns (bool) {
        return auctionAllowedTokens[auctionId][token];
    }

    /**
     * @notice Get minimum price for a token in an auction
     * @param auctionId The auction ID
     * @param token The token address
     * @return The minimum price
     */
    function getAuctionMinPrice(uint256 auctionId, address token) external view returns (uint256) {
        return auctionMinPrices[auctionId][token];
    }

    /// @notice Allow contract to receive ETH
    receive() external payable {}
}