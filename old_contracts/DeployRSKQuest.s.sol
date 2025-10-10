// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {RSKQuest} from "../src/RSKQuest.sol";

/**
 * @title Deployment Script for RSKQuest
 * @dev Secure deployment script with multiple configuration options
 */
contract DeployRSKQuest is Script {
    
    // Default configuration
    string constant DEFAULT_NAME = "RSK Quest";
    string constant DEFAULT_SYMBOL = "RSKQ";
    
    function run() external {
        // Get deployment configuration
        address initialOwner = getInitialOwner();
        
        console.log("=== DEPLOYMENT CONFIGURATION ===");
        console.log("Deployer:", msg.sender);
        console.log("Initial Owner:", initialOwner);
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        // Deploy the contract
        RSKQuest certificates = new RSKQuest(initialOwner);
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Log deployment info
        console.log("=== DEPLOYMENT SUCCESSFUL ===");
        console.log("Contract Address:", address(certificates));
        console.log("Name:", certificates.name());
        console.log("Symbol:", certificates.symbol());
        console.log("Owner:", certificates.owner());
        console.log("Next Token ID:", certificates.getNextTokenId());
        
        // Save deployment info to file
        saveDeploymentInfo(address(certificates), initialOwner);
        
        // Verify deployment
        verifyDeployment(certificates);
    }
    
    /**
     * @dev Get initial owner address from environment or use deployer
     */
    function getInitialOwner() internal view returns (address) {
        // Try to get from environment variable
        try vm.envAddress("INITIAL_OWNER") returns (address owner) {
            require(owner != address(0), "Invalid initial owner address");
            return owner;
        } catch {
            // Fallback to deployer address
            console.log("INITIAL_OWNER not set, using deployer address");
            return msg.sender;
        }
    }
    
    /**
     * @dev Save deployment information to a file
     */
    function saveDeploymentInfo(address contractAddress, address owner) internal {
        string memory chainId = vm.toString(block.chainid);
        string memory deploymentInfo = string(abi.encodePacked(
            "{\n",
            '  "contractName": "VquestsCertificates",\n',
            '  "contractAddress": "', vm.toString(contractAddress), '",\n',
            '  "owner": "', vm.toString(owner), '",\n',
            '  "chainId": ', chainId, ',\n',
            '  "blockNumber": ', vm.toString(block.number), ',\n',
            '  "timestamp": ', vm.toString(block.timestamp), ',\n',
            '  "deployer": "', vm.toString(msg.sender), '"\n',
            "}"
        ));
        
        string memory filename = string(abi.encodePacked(
            "./deployments/RSKQuest_",
            chainId,
            ".json"
        ));
        
        // Note: Deployment info will be saved manually if needed
        console.log("Deployment completed successfully!");
        console.log("Contract can be verified at: https://sepolia.basescan.org/address/");
        console.log("Contract address:", contractAddress);
    }
    
    /**
     * @dev Verify the deployment was successful
     */
    function verifyDeployment(RSKQuest certificates) internal view {
        console.log("=== DEPLOYMENT VERIFICATION ===");
        
        // Check basic contract state
        require(bytes(certificates.name()).length > 0, "Contract name not set");
        require(bytes(certificates.symbol()).length > 0, "Contract symbol not set");
        require(certificates.owner() != address(0), "Owner not set");
        require(certificates.getNextTokenId() == 1, "Initial token ID incorrect");
        
        console.log("[OK] Contract name verified");
        console.log("[OK] Contract symbol verified");
        console.log("[OK] Owner verified");
        console.log("[OK] Initial state verified");
        console.log("[OK] All verifications passed!");
    }
}
