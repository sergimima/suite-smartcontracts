// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/KukuxumusuNFTFactory.sol";

/**
 * @title CreateKukuxumusuCollection
 * @dev Script to create a new NFT collection using the factory
 * @notice Run with: forge script script/CreateKukuxumusuCollection.s.sol:CreateKukuxumusuCollection --rpc-url <STORY_RPC_URL> --broadcast
 */
contract CreateKukuxumusuCollection is Script {
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("TECNICO_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Factory contract address (deploy first)
        address factoryAddress = vm.envAddress("NFT_FACTORY_ADDRESS");
        
        // Collection configuration
        string memory name = vm.envOr("COLLECTION_NAME", string("Kukuxumusu Collection"));
        string memory symbol = vm.envOr("COLLECTION_SYMBOL", string("KUKU"));
        string memory baseURI = vm.envOr("COLLECTION_BASE_URI", string("ipfs://"));
        uint256 maxSupply = vm.envOr("COLLECTION_MAX_SUPPLY", uint256(10000));
        address collectionOwner = vm.envOr("COLLECTION_OWNER", deployer);
        address royaltyReceiver = vm.envOr("ROYALTY_RECEIVER", address(0));
        uint96 royaltyFee = uint96(vm.envOr("ROYALTY_FEE", uint256(0)));

        console.log("Creating new NFT collection...");
        console.log("Factory:", factoryAddress);
        console.log("Name:", name);
        console.log("Symbol:", symbol);
        console.log("Max Supply:", maxSupply);
        console.log("Owner:", collectionOwner);

        vm.startBroadcast(deployerPrivateKey);

        // Get factory contract
        KukuxumusuNFTFactory factory = KukuxumusuNFTFactory(factoryAddress);

        // Create collection configuration
        KukuxumusuNFTFactory.CollectionConfig memory config = KukuxumusuNFTFactory.CollectionConfig({
            name: name,
            symbol: symbol,
            baseURI: baseURI,
            maxSupply: maxSupply,
            owner: collectionOwner,
            royaltyReceiver: royaltyReceiver,
            royaltyFee: royaltyFee
        });

        // Create the collection
        (uint256 collectionId, address collectionAddress) = factory.createCollection(config);

        console.log("Collection created!");
        console.log("Collection ID:", collectionId);
        console.log("Collection Address:", collectionAddress);

        vm.stopBroadcast();

        console.log("\n=== Collection Summary ===");
        console.log("Collection ID:", collectionId);
        console.log("Collection Address:", collectionAddress);
        console.log("Name:", name);
        console.log("Symbol:", symbol);
        console.log("Max Supply:", maxSupply);
        console.log("Owner:", collectionOwner);
        console.log("========================\n");

        // Save collection info
        string memory collectionInfo = string(
            abi.encodePacked(
                "Collection ID: ", vm.toString(collectionId), "\n",
                "Collection Address: ", vm.toString(collectionAddress), "\n",
                "Name: ", name, "\n",
                "Symbol: ", symbol, "\n",
                "Max Supply: ", vm.toString(maxSupply), "\n",
                "Owner: ", vm.toString(collectionOwner), "\n"
            )
        );

        string memory filename = string(abi.encodePacked("deployments/collection-", vm.toString(collectionId), ".txt"));
        vm.writeFile(filename, collectionInfo);
    }
}

