// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/KukuxumusuNFTFactory.sol";

/**
 * @title DeployKukuxumusuNFTFactory
 * @dev Deploy script for KukuxumusuNFTFactory contract on Story Protocol
 * @notice Run with: forge script script/DeployKukuxumusuNFTFactory.s.sol:DeployKukuxumusuNFTFactory --rpc-url <STORY_RPC_URL> --broadcast --verify
 */
contract DeployKukuxumusuNFTFactory is Script {
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("TECNICO_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER_ADDRESS", deployer);

        console.log("Deploying KukuxumusuNFTFactory contract...");
        console.log("Deployer:", deployer);
        console.log("Owner:", owner);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the NFT factory contract
        KukuxumusuNFTFactory factory = new KukuxumusuNFTFactory(deployer);

        console.log("KukuxumusuNFTFactory deployed at:", address(factory));

        // Transfer ownership if different from deployer
        if (owner != deployer) {
            factory.transferOwnership(owner);
            console.log("Ownership transferred to:", owner);
        }

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Contract: KukuxumusuNFTFactory");
        console.log("Address:", address(factory));
        console.log("Owner:", owner);
        console.log("========================\n");

        // Save deployment info
        string memory deploymentInfo = string(
            abi.encodePacked(
                "KukuxumusuNFTFactory deployed at: ", vm.toString(address(factory)), "\n",
                "Owner: ", vm.toString(owner), "\n"
            )
        );

        vm.writeFile("deployments/kukuxumusu-nft-factory-story.txt", deploymentInfo);
    }
}

