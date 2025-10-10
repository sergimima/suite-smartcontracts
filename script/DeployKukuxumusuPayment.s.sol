// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/KukuxumusuPayment.sol";

/**
 * @title DeployKukuxumusuPayment
 * @dev Deploy script for KukuxumusuPayment contract on Base network
 * @notice Run with: forge script script/DeployKukuxumusuPayment.s.sol:DeployKukuxumusuPayment --rpc-url <BASE_RPC_URL> --broadcast --verify
 */
contract DeployKukuxumusuPayment is Script {
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("TECNICO_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address owner = vm.envOr("OWNER_ADDRESS", deployer);
        address trustedSigner = vm.envOr("TRUSTED_SIGNER_ADDRESS", deployer);

        // Token addresses on Base (update these with actual addresses)
        address vtnToken = vm.envOr("VTN_TOKEN_ADDRESS", address(0));
        address usdtToken = vm.envOr("USDT_TOKEN_ADDRESS", address(0));

        // NFT contract addresses (from Story Protocol)
        address nftContract1 = vm.envOr("NFT_CONTRACT_1", address(0));
        address nftContract2 = vm.envOr("NFT_CONTRACT_2", address(0));

        console.log("Deploying KukuxumusuPayment contract...");
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);
        console.log("Owner:", owner);
        console.log("Trusted Signer:", trustedSigner);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the payment contract (deployer will be initial admin)
        KukuxumusuPayment payment = new KukuxumusuPayment(treasury, deployer, trustedSigner);

        console.log("KukuxumusuPayment deployed at:", address(payment));

        // Configure allowed payment tokens
        if (vtnToken != address(0)) {
            payment.setAllowedPaymentToken(vtnToken, true);
            console.log("VTN token allowed:", vtnToken);
        }

        if (usdtToken != address(0)) {
            payment.setAllowedPaymentToken(usdtToken, true);
            console.log("USDT token allowed:", usdtToken);
        }

        // Allow native ETH
        payment.setAllowedPaymentToken(address(0), true);
        console.log("Native ETH allowed");

        // Configure allowed NFT contracts
        if (nftContract1 != address(0)) {
            payment.setAllowedNFTContract(nftContract1, true);
            console.log("NFT Contract 1 allowed:", nftContract1);
        }

        if (nftContract2 != address(0)) {
            payment.setAllowedNFTContract(nftContract2, true);
            console.log("NFT Contract 2 allowed:", nftContract2);
        }

        // Grant roles to owner if different from deployer
        if (owner != deployer) {
            payment.grantRole(payment.DEFAULT_ADMIN_ROLE(), owner);
            payment.grantRole(payment.AUCTION_CREATOR_ROLE(), owner);
            console.log("Roles granted to:", owner);
        }

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Contract: KukuxumusuPayment");
        console.log("Address:", address(payment));
        console.log("Treasury:", treasury);
        console.log("Owner:", owner);
        console.log("========================\n");

        // Save deployment info
        string memory deploymentInfo = string(
            abi.encodePacked(
                "KukuxumusuPayment deployed at: ", vm.toString(address(payment)), "\n",
                "Treasury: ", vm.toString(treasury), "\n",
                "Owner: ", vm.toString(owner), "\n"
            )
        );

        vm.writeFile("deployments/kukuxumusu-payment-base.txt", deploymentInfo);
    }
}