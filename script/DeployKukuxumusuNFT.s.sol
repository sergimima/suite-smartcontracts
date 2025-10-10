// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/KukuxumusuNFT.sol";

/**
 * @title DeployKukuxumusuNFT
 * @dev Deploy script for KukuxumusuNFT contract on Story Protocol
 * @notice Run with: forge script script/DeployKukuxumusuNFT.s.sol:DeployKukuxumusuNFT --rpc-url <STORY_RPC_URL> --broadcast --verify
 */
contract DeployKukuxumusuNFT is Script {
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("TECNICO_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // NFT Configuration
        string memory name = vm.envOr("NFT_NAME", string("Kukuxumusu NFT"));
        string memory symbol = vm.envOr("NFT_SYMBOL", string("KUKU"));
        string memory baseURI = vm.envOr("NFT_BASE_URI", string("ipfs://"));
        uint256 maxSupply = vm.envOr("NFT_MAX_SUPPLY", uint256(0)); // 0 = unlimited
        address owner = vm.envOr("OWNER_ADDRESS", deployer);
        address royaltyReceiver = vm.envOr("ROYALTY_RECEIVER", owner);
        uint96 royaltyFee = uint96(vm.envOr("ROYALTY_FEE", uint256(500))); // 500 = 5%

        console.log("Deploying KukuxumusuNFT contract...");
        console.log("Deployer:", deployer);
        console.log("Name:", name);
        console.log("Symbol:", symbol);
        console.log("Base URI:", baseURI);
        console.log("Max Supply:", maxSupply == 0 ? "Unlimited" : vm.toString(maxSupply));
        console.log("Owner:", owner);
        console.log("Royalty Receiver:", royaltyReceiver);
        console.log("Royalty Fee:", royaltyFee, "basis points");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the NFT contract
        KukuxumusuNFT nft = new KukuxumusuNFT(
            name,
            symbol,
            baseURI,
            maxSupply,
            owner,
            royaltyReceiver,
            royaltyFee
        );

        console.log("KukuxumusuNFT deployed at:", address(nft));

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Contract: KukuxumusuNFT");
        console.log("Address:", address(nft));
        console.log("Owner:", owner);
        console.log("Max Supply:", maxSupply == 0 ? "Unlimited" : vm.toString(maxSupply));
        console.log("========================\n");

        // Save deployment info
        string memory deploymentInfo = string(
            abi.encodePacked(
                "KukuxumusuNFT deployed at: ", vm.toString(address(nft)), "\n",
                "Name: ", name, "\n",
                "Symbol: ", symbol, "\n",
                "Owner: ", vm.toString(owner), "\n",
                "Max Supply: ", maxSupply == 0 ? "Unlimited" : vm.toString(maxSupply), "\n"
            )
        );

        vm.writeFile("deployments/kukuxumusu-nft-story.txt", deploymentInfo);
    }
}