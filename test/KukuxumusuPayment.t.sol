// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/KukuxumusuPayment.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract KukuxumusuPaymentTest is Test {
    KukuxumusuPayment public payment;
    MockERC20 public vtn;
    MockERC20 public usdt;

    address public owner;
    address public treasury;
    address public buyer1;
    address public buyer2;
    address public buyer3;
    address public nftContract;

    // Trusted signer for signature verification
    uint256 public trustedSignerPrivateKey;
    address public trustedSigner;

    uint256 public constant NFT_ID = 1;
    uint256 public constant ETH_PRICE = 0.1 ether;
    uint256 public constant VTN_PRICE = 100 * 10**18;
    uint256 public constant USDT_PRICE = 50 * 10**18;

    event DirectPurchase(address indexed buyer, uint256 indexed nftId, address token, uint256 amount);
    event AuctionCreated(uint256 indexed auctionId, uint256 indexed nftId, uint256 startTime, uint256 endTime, address[] allowedTokens);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, address token, uint256 amount, uint256 valueInUSD, uint256 timestamp);
    event AuctionWon(uint256 indexed auctionId, address indexed winner, address indexed nftContract, uint256 nftId, address token, uint256 finalAmount, uint256 valueInUSD);

    function setUp() public {
        owner = address(this);
        treasury = makeAddr("treasury");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        buyer3 = makeAddr("buyer3");

        // Setup trusted signer
        trustedSignerPrivateKey = 0x1234;
        trustedSigner = vm.addr(trustedSignerPrivateKey);

        // Deploy mock tokens
        vtn = new MockERC20("Vottun Token", "VTN");
        usdt = new MockERC20("USD Tether", "USDT");

        // Create mock NFT contract address
        nftContract = makeAddr("nftContract");

        // Deploy payment contract
        payment = new KukuxumusuPayment(treasury, owner, trustedSigner);

        // Configure payment tokens
        payment.setAllowedPaymentToken(address(0), true); // ETH
        payment.setAllowedPaymentToken(address(vtn), true);
        payment.setAllowedPaymentToken(address(usdt), true);

        // Configure NFT contract
        payment.setAllowedNFTContract(nftContract, true);

        // Set prices
        payment.setPrice(nftContract, NFT_ID, address(0), ETH_PRICE);
        payment.setPrice(nftContract, NFT_ID, address(vtn), VTN_PRICE);
        payment.setPrice(nftContract, NFT_ID, address(usdt), USDT_PRICE);

        // Fund buyers
        vm.deal(buyer1, 10 ether);
        vm.deal(buyer2, 10 ether);
        vm.deal(buyer3, 10 ether);

        vtn.mint(buyer1, 1000 * 10**18);
        vtn.mint(buyer2, 1000 * 10**18);
        usdt.mint(buyer1, 1000 * 10**18);
        usdt.mint(buyer3, 1000 * 10**18);
    }

    // ===== DIRECT PURCHASE TESTS =====

    function test_DirectPurchaseWithETH() public {
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(buyer1);
        vm.expectEmit(true, true, false, true);
        emit DirectPurchase(buyer1, NFT_ID, address(0), ETH_PRICE);
        payment.directPurchase{value: ETH_PRICE}(nftContract, NFT_ID, address(0), ETH_PRICE);

        assertEq(treasury.balance, treasuryBalanceBefore + ETH_PRICE);
    }

    function test_DirectPurchaseWithVTN() public {
        vm.startPrank(buyer1);
        vtn.approve(address(payment), VTN_PRICE);

        uint256 treasuryBalanceBefore = vtn.balanceOf(treasury);

        vm.expectEmit(true, true, false, true);
        emit DirectPurchase(buyer1, NFT_ID, address(vtn), VTN_PRICE);
        payment.directPurchase(nftContract, NFT_ID, address(vtn), VTN_PRICE);

        assertEq(vtn.balanceOf(treasury), treasuryBalanceBefore + VTN_PRICE);
        vm.stopPrank();
    }

    function test_DirectPurchaseWithUSDT() public {
        vm.startPrank(buyer1);
        usdt.approve(address(payment), USDT_PRICE);

        uint256 treasuryBalanceBefore = usdt.balanceOf(treasury);

        payment.directPurchase(nftContract, NFT_ID, address(usdt), USDT_PRICE);

        assertEq(usdt.balanceOf(treasury), treasuryBalanceBefore + USDT_PRICE);
        vm.stopPrank();
    }

    function test_RevertWhen_DirectPurchaseWithNotAllowedToken() public {
        MockERC20 notAllowed = new MockERC20("Not Allowed", "NA");
        notAllowed.mint(buyer1, 1000 * 10**18);

        vm.startPrank(buyer1);
        notAllowed.approve(address(payment), 100 * 10**18);
        vm.expectRevert("Payment token not allowed");
        payment.directPurchase(nftContract, NFT_ID, address(notAllowed), 100 * 10**18);
        vm.stopPrank();
    }

    function test_RevertWhen_DirectPurchaseWithIncorrectAmount() public {
        vm.prank(buyer1);
        vm.expectRevert("Incorrect payment amount");
        payment.directPurchase{value: 0.05 ether}(nftContract, NFT_ID, address(0), 0.05 ether);
    }

    function test_DirectPurchaseWhenPaused() public {
        payment.pause();

        vm.prank(buyer1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        payment.directPurchase{value: ETH_PRICE}(nftContract, NFT_ID, address(0), ETH_PRICE);

        payment.unpause();

        vm.prank(buyer1);
        payment.directPurchase{value: ETH_PRICE}(nftContract, NFT_ID, address(0), ETH_PRICE);
    }

    // ===== AUCTION TESTS =====

    function test_CreateAuction() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(0);
        tokens[1] = address(vtn);

        uint256[] memory minPrices = new uint256[](2);
        minPrices[0] = 0.05 ether;
        minPrices[1] = 50 * 10**18;

        uint256[] memory discounts = new uint256[](2);
        discounts[0] = 0;
        discounts[1] = 10; // 10% discount for VTN

        uint256 duration = 1 days;

        vm.expectEmit(true, true, false, false);
        emit AuctionCreated(0, NFT_ID, block.timestamp, block.timestamp + duration, tokens);

        payment.createAuction(nftContract, NFT_ID, 0, duration, tokens, minPrices, discounts, 10 minutes, 5 minutes);

        (
            address nftContractAuction,
            uint256 nftId,
            uint256 startTime,
            uint256 endTime,
            address highestBidder,
            ,
            uint256 highestBid,
            ,
            bool finalized,
            ,

        ) = payment.auctions(0);

        assertEq(nftContractAuction, nftContract);
        assertEq(nftId, NFT_ID);
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + duration);
        assertEq(highestBidder, address(0));
        assertEq(highestBid, 0);
        assertFalse(finalized);
    }

    function test_PlaceBidWithETH() public {
        _createBasicAuction();

        uint256 bidAmount = 0.1 ether;
        uint256 valueInUSD = 100 * 10**18; // 100 USD

        bytes memory signature = _generateSignature(0, buyer1, address(0), bidAmount, valueInUSD);

        vm.prank(buyer1);
        vm.expectEmit(true, true, false, false);
        emit BidPlaced(0, buyer1, address(0), bidAmount, valueInUSD, block.timestamp);
        payment.placeBid{value: bidAmount}(0, address(0), bidAmount, valueInUSD, signature);

        (, , , , address highestBidder, , uint256 highestBid, , , , ) = payment.auctions(0);
        assertEq(highestBidder, buyer1);
        assertEq(highestBid, bidAmount);
    }

    function test_PlaceBidWithToken() public {
        _createBasicAuction();

        uint256 bidAmount = 100 * 10**18;
        uint256 valueInUSD = 120 * 10**18; // 120 USD

        bytes memory signature = _generateSignature(0, buyer1, address(vtn), bidAmount, valueInUSD);

        vm.startPrank(buyer1);
        vtn.approve(address(payment), bidAmount);
        payment.placeBid(0, address(vtn), bidAmount, valueInUSD, signature);
        vm.stopPrank();

        (, , , , address highestBidder, , uint256 highestBid, , , , ) = payment.auctions(0);
        assertEq(highestBidder, buyer1);
        assertEq(highestBid, bidAmount);
    }

    function test_MultipleBids() public {
        _createBasicAuction();

        // Buyer1 bids
        uint256 bid1 = 0.1 ether;
        uint256 usd1 = 100 * 10**18;
        bytes memory sig1 = _generateSignature(0, buyer1, address(0), bid1, usd1);
        vm.prank(buyer1);
        payment.placeBid{value: bid1}(0, address(0), bid1, usd1, sig1);

        // Buyer2 bids higher
        uint256 bid2 = 0.15 ether;
        uint256 usd2 = 150 * 10**18;
        bytes memory sig2 = _generateSignature(0, buyer2, address(0), bid2, usd2);
        vm.prank(buyer2);
        payment.placeBid{value: bid2}(0, address(0), bid2, usd2, sig2);

        // Buyer3 bids even higher
        uint256 bid3 = 0.2 ether;
        uint256 usd3 = 200 * 10**18;
        bytes memory sig3 = _generateSignature(0, buyer3, address(0), bid3, usd3);
        vm.prank(buyer3);
        payment.placeBid{value: bid3}(0, address(0), bid3, usd3, sig3);

        (, , , , address highestBidder, , uint256 highestBid, , , , ) = payment.auctions(0);
        assertEq(highestBidder, buyer3);
        assertEq(highestBid, 0.2 ether);

        // Check buyer1 has pending refund
        assertEq(payment.getPendingRefund(buyer1, address(0)), 0.1 ether);
        // Check buyer2 has pending refund
        assertEq(payment.getPendingRefund(buyer2, address(0)), 0.15 ether);
    }

    function test_WithdrawRefund() public {
        _createBasicAuction();

        // Buyer1 bids
        uint256 bid1 = 0.1 ether;
        uint256 usd1 = 100 * 10**18;
        bytes memory sig1 = _generateSignature(0, buyer1, address(0), bid1, usd1);
        vm.prank(buyer1);
        payment.placeBid{value: bid1}(0, address(0), bid1, usd1, sig1);

        // Buyer2 bids higher
        uint256 bid2 = 0.15 ether;
        uint256 usd2 = 150 * 10**18;
        bytes memory sig2 = _generateSignature(0, buyer2, address(0), bid2, usd2);
        vm.prank(buyer2);
        payment.placeBid{value: bid2}(0, address(0), bid2, usd2, sig2);

        // Buyer1 should have refund
        uint256 buyer1BalanceBefore = buyer1.balance;

        vm.prank(buyer1);
        payment.withdrawRefund(address(0));

        assertEq(buyer1.balance, buyer1BalanceBefore + 0.1 ether);
        assertEq(payment.getPendingRefund(buyer1, address(0)), 0);
    }

    function test_FinalizeAuction() public {
        _createBasicAuction();

        // Place winning bid
        uint256 bid = 0.1 ether;
        uint256 usd = 100 * 10**18;
        bytes memory sig = _generateSignature(0, buyer1, address(0), bid, usd);
        vm.prank(buyer1);
        payment.placeBid{value: bid}(0, address(0), bid, usd, sig);

        // Fast forward past auction end
        vm.warp(block.timestamp + 1 days + 1);

        uint256 treasuryBalanceBefore = treasury.balance;

        vm.expectEmit(true, true, true, true);
        emit AuctionWon(0, buyer1, nftContract, NFT_ID, address(0), 0.1 ether, usd);
        payment.finalizeAuction(0);

        assertEq(treasury.balance, treasuryBalanceBefore + 0.1 ether);

        (, , , , , , , , bool finalized, , ) = payment.auctions(0);
        assertTrue(finalized);
    }

    function test_RevertWhen_FinalizeAuctionTooEarly() public {
        _createBasicAuction();

        uint256 bid = 0.1 ether;
        uint256 usd = 100 * 10**18;
        bytes memory sig = _generateSignature(0, buyer1, address(0), bid, usd);
        vm.prank(buyer1);
        payment.placeBid{value: bid}(0, address(0), bid, usd, sig);

        // Try to finalize before end
        vm.expectRevert("Auction not ended yet");
        payment.finalizeAuction(0);
    }

    function test_RevertWhen_BidAfterAuctionEnds() public {
        _createBasicAuction();

        // Fast forward past auction end
        vm.warp(block.timestamp + 1 days + 1);

        uint256 bid = 0.1 ether;
        uint256 usd = 100 * 10**18;
        bytes memory sig = _generateSignature(0, buyer1, address(0), bid, usd);
        vm.prank(buyer1);
        vm.expectRevert("Auction ended");
        payment.placeBid{value: bid}(0, address(0), bid, usd, sig);
    }

    function test_RevertWhen_BidBelowMinimum() public {
        _createBasicAuction();

        uint256 bid = 0.01 ether;
        uint256 usd = 10 * 10**18;
        bytes memory sig = _generateSignature(0, buyer1, address(0), bid, usd);
        vm.prank(buyer1);
        vm.expectRevert("Bid below minimum price");
        payment.placeBid{value: bid}(0, address(0), bid, usd, sig);
    }

    function test_AntiSniping() public {
        _createBasicAuction();

        // Fast forward to near end (within trigger time)
        vm.warp(block.timestamp + 1 days - 4 minutes);

        (, , , uint256 endTimeBefore, , , , , , , ) = payment.auctions(0);

        // Place bid
        uint256 bid = 0.1 ether;
        uint256 usd = 100 * 10**18;
        bytes memory sig = _generateSignature(0, buyer1, address(0), bid, usd);
        vm.prank(buyer1);
        payment.placeBid{value: bid}(0, address(0), bid, usd, sig);

        (, , , uint256 endTimeAfter, , , , , , , ) = payment.auctions(0);

        // Check that end time was extended
        assertEq(endTimeAfter, endTimeBefore + 10 minutes);
    }

    function test_FinalizeAuctionWithNoBids() public {
        _createBasicAuction();

        // Fast forward past auction end
        vm.warp(block.timestamp + 1 days + 1);

        payment.finalizeAuction(0);

        (, , , , , , , , bool finalized, , ) = payment.auctions(0);
        assertTrue(finalized);
    }

    // ===== ADMIN TESTS =====

    function test_SetPrice() public {
        uint256 newPrice = 0.2 ether;
        payment.setPrice(nftContract, 2, address(0), newPrice);
        assertEq(payment.prices(nftContract, 2, address(0)), newPrice);
    }

    function test_SetTreasury() public {
        address newTreasury = makeAddr("newTreasury");
        payment.setTreasury(newTreasury);
        assertEq(payment.treasury(), newTreasury);
    }

    function test_SetAllowedPaymentToken() public {
        MockERC20 newToken = new MockERC20("New Token", "NEW");
        payment.setAllowedPaymentToken(address(newToken), true);
        assertTrue(payment.allowedPaymentTokens(address(newToken)));
    }

    function test_Withdraw() public {
        // Send some ETH to contract
        vm.deal(address(payment), 1 ether);

        uint256 ownerBalanceBefore = owner.balance;
        payment.withdraw(address(0), 1 ether);
        assertEq(owner.balance, ownerBalanceBefore + 1 ether);
    }

    // Receive function to accept ETH
    receive() external payable {}

    function test_WithdrawToken() public {
        // Send some tokens to contract
        vtn.mint(address(payment), 100 * 10**18);

        uint256 ownerBalanceBefore = vtn.balanceOf(owner);
        payment.withdraw(address(vtn), 100 * 10**18);
        assertEq(vtn.balanceOf(owner), ownerBalanceBefore + 100 * 10**18);
    }

    function test_RevertWhen_NonOwnerSetPrice() public {
        vm.prank(buyer1);
        vm.expectRevert();
        payment.setPrice(nftContract, 2, address(0), 0.2 ether);
    }

    function test_RevertWhen_NonOwnerPause() public {
        vm.prank(buyer1);
        vm.expectRevert();
        payment.pause();
    }

    // ===== DISCOUNT TESTS =====

    function test_AuctionWithDiscount() public {
        // Create auction with discount on VTN
        address[] memory tokens = new address[](2);
        tokens[0] = address(0);
        tokens[1] = address(vtn);

        uint256[] memory minPrices = new uint256[](2);
        minPrices[0] = 0.05 ether;
        minPrices[1] = 50 * 10**18;

        uint256[] memory discounts = new uint256[](2);
        discounts[0] = 0;
        discounts[1] = 20; // 20% discount for VTN

        payment.createAuction(nftContract, NFT_ID, 0, 1 days, tokens, minPrices, discounts, 10 minutes, 5 minutes);

        // Place winning bid with VTN
        uint256 bidAmount = 100 * 10**18; // 100 VTN
        uint256 valueInUSD = 100 * 10**18; // 100 USD
        bytes memory sig = _generateSignature(0, buyer1, address(vtn), bidAmount, valueInUSD);

        vm.startPrank(buyer1);
        vtn.approve(address(payment), bidAmount);
        payment.placeBid(0, address(vtn), bidAmount, valueInUSD, sig);
        vm.stopPrank();

        // Fast forward past auction end
        vm.warp(block.timestamp + 1 days + 1);

        uint256 treasuryBalanceBefore = vtn.balanceOf(treasury);
        uint256 buyer1BalanceBefore = vtn.balanceOf(buyer1);

        // Finalize auction
        payment.finalizeAuction(0);

        // Check treasury received 80 VTN (100 - 20% discount)
        uint256 expectedPayment = (bidAmount * 80) / 100; // 80 VTN
        assertEq(vtn.balanceOf(treasury), treasuryBalanceBefore + expectedPayment);

        // Check buyer1 has 20 VTN refund pending
        uint256 expectedRefund = bidAmount - expectedPayment; // 20 VTN
        assertEq(payment.getPendingRefund(buyer1, address(vtn)), expectedRefund);

        // Withdraw refund
        vm.prank(buyer1);
        payment.withdrawRefund(address(vtn));

        // Check buyer1 received the refund
        assertEq(vtn.balanceOf(buyer1), buyer1BalanceBefore + expectedRefund);
    }

    function test_AuctionWithNoDiscount() public {
        _createBasicAuction();

        // Place winning bid with ETH (no discount)
        uint256 bidAmount = 0.1 ether;
        uint256 valueInUSD = 100 * 10**18;
        bytes memory sig = _generateSignature(0, buyer1, address(0), bidAmount, valueInUSD);

        vm.prank(buyer1);
        payment.placeBid{value: bidAmount}(0, address(0), bidAmount, valueInUSD, sig);

        // Fast forward past auction end
        vm.warp(block.timestamp + 1 days + 1);

        uint256 treasuryBalanceBefore = treasury.balance;

        // Finalize auction
        payment.finalizeAuction(0);

        // Check treasury received full amount (no discount)
        assertEq(treasury.balance, treasuryBalanceBefore + bidAmount);

        // Check no refund for buyer1
        assertEq(payment.getPendingRefund(buyer1, address(0)), 0);
    }

    // ===== SIGNATURE VERIFICATION TESTS =====

    function test_RevertWhen_InvalidSignature() public {
        _createBasicAuction();

        uint256 bidAmount = 0.1 ether;
        uint256 valueInUSD = 100 * 10**18;

        // Generate signature with wrong private key
        uint256 wrongPrivateKey = 0x9999;
        bytes32 messageHash = keccak256(abi.encodePacked(uint256(0), buyer1, address(0), bidAmount, valueInUSD));
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, ethSignedMessageHash);
        bytes memory wrongSig = abi.encodePacked(r, s, v);

        vm.prank(buyer1);
        vm.expectRevert("Invalid signature");
        payment.placeBid{value: bidAmount}(0, address(0), bidAmount, valueInUSD, wrongSig);
    }

    function test_RevertWhen_SignatureWithWrongData() public {
        _createBasicAuction();

        uint256 bidAmount = 0.1 ether;
        uint256 valueInUSD = 100 * 10**18;

        // Generate signature with correct key but wrong data (wrong USD value)
        uint256 wrongUSD = 200 * 10**18;
        bytes memory sig = _generateSignature(0, buyer1, address(0), bidAmount, wrongUSD);

        vm.prank(buyer1);
        vm.expectRevert("Invalid signature");
        payment.placeBid{value: bidAmount}(0, address(0), bidAmount, valueInUSD, sig);
    }

    function test_SetTrustedSigner() public {
        address newSigner = makeAddr("newSigner");
        payment.setTrustedSigner(newSigner);
        assertEq(payment.trustedSigner(), newSigner);
    }

    function test_RevertWhen_NonAdminSetTrustedSigner() public {
        address newSigner = makeAddr("newSigner");
        vm.prank(buyer1);
        vm.expectRevert();
        payment.setTrustedSigner(newSigner);
    }

    // ===== HELPER FUNCTIONS =====

    function _generateSignature(
        uint256 auctionId,
        address bidder,
        address paymentToken,
        uint256 amount,
        uint256 valueInUSD
    ) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encodePacked(auctionId, bidder, paymentToken, amount, valueInUSD));
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(trustedSignerPrivateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    function _createBasicAuction() internal {
        address[] memory tokens = new address[](2);
        tokens[0] = address(0);
        tokens[1] = address(vtn);

        uint256[] memory minPrices = new uint256[](2);
        minPrices[0] = 0.05 ether;
        minPrices[1] = 50 * 10**18;

        uint256[] memory discounts = new uint256[](2);
        discounts[0] = 0; // 0% discount for ETH
        discounts[1] = 0; // 0% discount for VTN

        payment.createAuction(nftContract, NFT_ID, 0, 1 days, tokens, minPrices, discounts, 10 minutes, 5 minutes);
    }
}