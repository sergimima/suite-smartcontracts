// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "@forge-std/Test.sol";
import {RSKQuest} from "../src/RSKQuest.sol";

contract ActivitiesPlatformCertificatesTest is Test {
    RSKQuest public certificatesContract;
    
    address public owner;
    address public user1;
    address public user2;
    
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy the contract
        certificatesContract = new RSKQuest(owner);
        
        console.log("ActivitiesPlatformCertificates deployed at:", address(certificatesContract));
    }
    
    function test_ContractDeployment() public {
        // Basic deployment test
        assertTrue(address(certificatesContract) != address(0));
        console.log("Contract successfully deployed");
    }
    
    // TODO: Add specific tests based on contract functionality
    // Examples of common test patterns:
    
    function test_InitialState() public {
        // Test initial contract state
        assertEq(certificatesContract.getNextTokenId(), 1);
        assertEq(certificatesContract.owner(), owner);
        assertEq(certificatesContract.name(), "Activities Platform Certificates");
        assertEq(certificatesContract.symbol(), "APC");
    }
    
    function test_OnlyOwnerCanMint() public {
        string memory campaignId = "campaign1";
        string memory tokenURI = "https://example.com/token/1";
        
        // Try to mint as non-owner (should fail)
        vm.prank(user1);
        vm.expectRevert();
        certificatesContract.mintCertificate(user2, tokenURI, campaignId);
        
        // Mint as owner (should succeed)
        certificatesContract.mintCertificate(user1, tokenURI, campaignId);
        assertTrue(certificatesContract.hasCampaignCertificate(user1, campaignId));
    }
    
    function test_MintCertificate() public {
        string memory campaignId = "campaign1";
        string memory tokenURI = "https://example.com/token/1";
        
        // Mint certificate
        uint256 tokenId = certificatesContract.mintCertificate(user1, tokenURI, campaignId);
        
        // Verify minting
        assertEq(tokenId, 1);
        assertEq(certificatesContract.ownerOf(tokenId), user1);
        assertEq(certificatesContract.tokenURI(tokenId), tokenURI);
        assertEq(certificatesContract.getCampaignId(tokenId), campaignId);
        assertTrue(certificatesContract.hasCampaignCertificate(user1, campaignId));
        assertEq(certificatesContract.campaignSupply(campaignId), 1);
    }
    
    function test_PreventDuplicateMinting() public {
        string memory campaignId = "campaign1";
        string memory tokenURI = "https://example.com/token/1";
        
        // First mint should succeed
        certificatesContract.mintCertificate(user1, tokenURI, campaignId);
        
        // Second mint to same user for same campaign should fail
        vm.expectRevert("User already minted for this campaign");
        certificatesContract.mintCertificate(user1, tokenURI, campaignId);
        
        // But different user should be able to mint
        certificatesContract.mintCertificate(user2, tokenURI, campaignId);
        assertEq(certificatesContract.campaignSupply(campaignId), 2);
    }
    
    function test_CertificateMintedEvent() public {
        string memory campaignId = "campaign1";
        string memory tokenURI = "https://example.com/token/1";
        
        // Expect the CertificateMinted event
        vm.expectEmit(true, true, true, true);
        emit RSKQuest.CertificateMinted(user1, 1, campaignId, "", tokenURI);
        
        // Mint certificate
        vm.prank(user1);
        certificatesContract.mintCertificate{value: 0.01 ether}(tokenURI, campaignId, "");
    }
    
    function testFuzz_FuzzTesting(uint256 randomValue) public {
        // Fuzz testing with random inputs
        // Foundry will automatically generate test cases
        vm.assume(randomValue > 0); // Add constraints as needed
    }
    
    // Helper functions
    function _helperFunction() internal {
        // Add helper functions for common test setup
    }
}
