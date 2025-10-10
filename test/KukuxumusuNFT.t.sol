// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/KukuxumusuNFT.sol";

contract KukuxumusuNFTTest is Test {
    KukuxumusuNFT public nft;

    address public owner;
    address public authorizedMinter;
    address public royaltyReceiver;
    address public user1;
    address public user2;
    address public unauthorizedUser;

    string public constant NAME = "Kukuxumusu NFT";
    string public constant SYMBOL = "KUKU";
    string public constant BASE_URI = "ipfs://QmExample/";
    uint256 public constant MAX_SUPPLY = 1000;
    uint96 public constant ROYALTY_FEE = 500; // 5%

    event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI, uint256 timestamp);
    event BatchMinted(address[] recipients, uint256[] tokenIds, uint256 timestamp);
    event AuthorizedMinterUpdated(address indexed minter, bool authorized);

    function setUp() public {
        owner = address(this);
        authorizedMinter = makeAddr("authorizedMinter");
        royaltyReceiver = makeAddr("royaltyReceiver");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        unauthorizedUser = makeAddr("unauthorizedUser");

        // Deploy NFT contract
        nft = new KukuxumusuNFT(
            NAME,
            SYMBOL,
            BASE_URI,
            MAX_SUPPLY,
            owner,
            royaltyReceiver,
            ROYALTY_FEE
        );

        // Authorize the minter
        nft.setAuthorizedMinter(authorizedMinter, true);
    }

    // ===== MINTING TESTS =====

    function test_MintByAuthorizedMinter() public {
        uint256 tokenId = 1;
        string memory tokenURI = "metadata1.json";

        vm.prank(authorizedMinter);
        vm.expectEmit(true, true, false, false);
        emit NFTMinted(user1, tokenId, tokenURI, block.timestamp);
        nft.mint(user1, tokenId, tokenURI);

        assertEq(nft.ownerOf(tokenId), user1);
        assertEq(nft.tokenURI(tokenId), string(abi.encodePacked(BASE_URI, tokenURI)));
        assertEq(nft.totalMinted(), 1);
    }

    function test_RevertWhen_MintByUnauthorizedUser() public {
        uint256 tokenId = 1;
        string memory tokenURI = "metadata1.json";

        vm.prank(unauthorizedUser);
        vm.expectRevert("Not an authorized minter");
        nft.mint(user1, tokenId, tokenURI);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        uint256 tokenId = 1;
        string memory tokenURI = "metadata1.json";

        vm.prank(authorizedMinter);
        vm.expectRevert("Cannot mint to zero address");
        nft.mint(address(0), tokenId, tokenURI);
    }

    function test_RevertWhen_MintWithEmptyTokenURI() public {
        uint256 tokenId = 1;

        vm.prank(authorizedMinter);
        vm.expectRevert("Token URI cannot be empty");
        nft.mint(user1, tokenId, "");
    }

    function test_RevertWhen_MintExceedMaxSupply() public {
        vm.startPrank(authorizedMinter);

        // Mint MAX_SUPPLY tokens
        for (uint256 i = 1; i <= MAX_SUPPLY; i++) {
            nft.mint(user1, i, string(abi.encodePacked("metadata", vm.toString(i), ".json")));
        }

        // Try to mint one more (should fail)
        vm.expectRevert("Max supply reached");
        nft.mint(user1, MAX_SUPPLY + 1, "metadata_extra.json");
        vm.stopPrank();
    }

    function test_BatchMint() public {
        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user1;

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        string[] memory tokenURIs = new string[](3);
        tokenURIs[0] = "metadata1.json";
        tokenURIs[1] = "metadata2.json";
        tokenURIs[2] = "metadata3.json";

        vm.prank(authorizedMinter);
        vm.expectEmit(false, false, false, false);
        emit BatchMinted(recipients, tokenIds, block.timestamp);
        nft.batchMint(recipients, tokenIds, tokenURIs);

        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.ownerOf(2), user2);
        assertEq(nft.ownerOf(3), user1);
        assertEq(nft.totalMinted(), 3);
    }

    function test_RevertWhen_BatchMintArrayLengthMismatch() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        string[] memory tokenURIs = new string[](2);
        tokenURIs[0] = "metadata1.json";
        tokenURIs[1] = "metadata2.json";

        vm.prank(authorizedMinter);
        vm.expectRevert("Array lengths mismatch");
        nft.batchMint(recipients, tokenIds, tokenURIs);
    }

    function test_RevertWhen_BatchMintExceedMaxSupply() public {
        address[] memory recipients = new address[](MAX_SUPPLY + 1);
        uint256[] memory tokenIds = new uint256[](MAX_SUPPLY + 1);
        string[] memory tokenURIs = new string[](MAX_SUPPLY + 1);

        for (uint256 i = 0; i < MAX_SUPPLY + 1; i++) {
            recipients[i] = user1;
            tokenIds[i] = i + 1;
            tokenURIs[i] = string(abi.encodePacked("metadata", vm.toString(i + 1), ".json"));
        }

        vm.prank(authorizedMinter);
        vm.expectRevert("Would exceed max supply");
        nft.batchMint(recipients, tokenIds, tokenURIs);
    }

    // ===== AUTHORIZATION TESTS =====

    function test_SetAuthorizedMinter() public {
        address newMinter = makeAddr("newMinter");

        vm.expectEmit(true, false, false, true);
        emit AuthorizedMinterUpdated(newMinter, true);
        nft.setAuthorizedMinter(newMinter, true);

        assertTrue(nft.authorizedMinters(newMinter));
    }

    function test_RemoveAuthorizedMinter() public {
        vm.expectEmit(true, false, false, true);
        emit AuthorizedMinterUpdated(authorizedMinter, false);
        nft.setAuthorizedMinter(authorizedMinter, false);

        assertFalse(nft.authorizedMinters(authorizedMinter));
    }

    function test_RevertWhen_NonOwnerSetAuthorizedMinter() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        nft.setAuthorizedMinter(unauthorizedUser, true);
    }

    // ===== BASE URI TESTS =====

    function test_SetBaseURI() public {
        string memory newBaseURI = "ipfs://QmNewExample/";
        nft.setBaseURI(newBaseURI);

        // Mint a token to test the new base URI
        vm.prank(authorizedMinter);
        nft.mint(user1, 1, "metadata1.json");

        assertEq(nft.tokenURI(1), string(abi.encodePacked(newBaseURI, "metadata1.json")));
    }

    function test_RevertWhen_NonOwnerSetBaseURI() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        nft.setBaseURI("ipfs://QmNewExample/");
    }

    // ===== ROYALTY TESTS (ERC-2981) =====

    function test_RoyaltyInfo() public {
        // Mint a token
        vm.prank(authorizedMinter);
        nft.mint(user1, 1, "metadata1.json");

        // Check royalty info
        uint256 salePrice = 1 ether;
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, (salePrice * ROYALTY_FEE) / 10000); // 5% of sale price
    }

    function test_UpdateRoyalty() public {
        address newReceiver = makeAddr("newRoyaltyReceiver");
        uint96 newFee = 1000; // 10%

        nft.updateRoyalty(newReceiver, newFee);

        // Mint a token
        vm.prank(authorizedMinter);
        nft.mint(user1, 1, "metadata1.json");

        // Check new royalty info
        uint256 salePrice = 1 ether;
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, salePrice);

        assertEq(receiver, newReceiver);
        assertEq(royaltyAmount, (salePrice * newFee) / 10000);
    }

    // ===== PAUSE TESTS =====

    function test_PauseAndUnpause() public {
        // Mint before pause
        vm.prank(authorizedMinter);
        nft.mint(user1, 1, "metadata1.json");

        // Pause
        nft.pause();

        // Try to mint while paused (should fail)
        vm.prank(authorizedMinter);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        nft.mint(user1, 2, "metadata2.json");

        // Unpause
        nft.unpause();

        // Mint after unpause (should succeed)
        vm.prank(authorizedMinter);
        nft.mint(user1, 2, "metadata2.json");

        assertEq(nft.totalMinted(), 2);
    }

    function test_PauseTransfers() public {
        // Mint a token
        vm.prank(authorizedMinter);
        nft.mint(user1, 1, "metadata1.json");

        // Pause
        nft.pause();

        // Try to transfer while paused (should fail)
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        nft.transferFrom(user1, user2, 1);

        // Unpause
        nft.unpause();

        // Transfer after unpause (should succeed)
        vm.prank(user1);
        nft.transferFrom(user1, user2, 1);

        assertEq(nft.ownerOf(1), user2);
    }

    function test_RevertWhen_NonOwnerPause() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        nft.pause();
    }

    // ===== TRANSFER TESTS =====

    function test_Transfer() public {
        // Mint a token
        vm.prank(authorizedMinter);
        nft.mint(user1, 1, "metadata1.json");

        // Transfer
        vm.prank(user1);
        nft.transferFrom(user1, user2, 1);

        assertEq(nft.ownerOf(1), user2);
    }

    function test_SafeTransfer() public {
        // Mint a token
        vm.prank(authorizedMinter);
        nft.mint(user1, 1, "metadata1.json");

        // Safe transfer
        vm.prank(user1);
        nft.safeTransferFrom(user1, user2, 1);

        assertEq(nft.ownerOf(1), user2);
    }

    // ===== MAX SUPPLY TESTS =====

    function test_RemainingSupply() public {
        if (MAX_SUPPLY == 0) {
            assertEq(nft.remainingSupply(), type(uint256).max);
        } else {
            assertEq(nft.remainingSupply(), MAX_SUPPLY);

            // Mint some tokens
            vm.startPrank(authorizedMinter);
            nft.mint(user1, 1, "metadata1.json");
            nft.mint(user1, 2, "metadata2.json");
            vm.stopPrank();

            assertEq(nft.remainingSupply(), MAX_SUPPLY - 2);
        }
    }

    // ===== METADATA TESTS =====

    function test_GetTokenMetadata() public {
        uint256 tokenId = 1;
        string memory tokenURI = "metadata1.json";

        vm.prank(authorizedMinter);
        nft.mint(user1, tokenId, tokenURI);

        string memory uri = nft.tokenURI(tokenId);
        assertEq(uri, string(abi.encodePacked(BASE_URI, tokenURI)));
    }

    function test_TokenURIConstruction() public {
        uint256 tokenId = 1;
        string memory tokenURI = "metadata1.json";

        vm.prank(authorizedMinter);
        nft.mint(user1, tokenId, tokenURI);

        string memory fullURI = nft.tokenURI(tokenId);
        assertEq(fullURI, string(abi.encodePacked(BASE_URI, tokenURI)));
    }

    // ===== INTERFACE SUPPORT TESTS =====

    function test_SupportsInterface() public view {
        // ERC721
        assertTrue(nft.supportsInterface(0x80ac58cd));
        // ERC2981
        assertTrue(nft.supportsInterface(0x2a55205a));
        // ERC165
        assertTrue(nft.supportsInterface(0x01ffc9a7));
    }
}