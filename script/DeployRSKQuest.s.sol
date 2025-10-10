// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../old_contracts/RSKQuest.sol";

/**
 * @title DeployRSKQuest
 * @dev Deploy script for RSKQuest contract on Rootstock
 */
contract DeployRSKQuest is Script {
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("TECNICO_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER_ADDRESS", deployer);

        console.log("Deploying RSKQuest contract...");
        console.log("Deployer:", deployer);
        console.log("Owner:", owner);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy RSKQuest
        RSKQuest rskQuest = new RSKQuest(owner);

        console.log("RSKQuest deployed at:", address(rskQuest));

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Contract: RSKQuest");
        console.log("Address:", address(rskQuest));
        console.log("Owner:", owner);
        console.log("========================\n");

        // Save deployment info
        string memory deploymentInfo = string(
            abi.encodePacked(
                "RSKQuest deployed at: ", vm.toString(address(rskQuest)), "\n",
                "Owner: ", vm.toString(owner), "\n",
                "Network: Rootstock Mainnet (Chain ID: 30)\n"
            )
        );

        vm.writeFile("deployments/rskquest-rootstock-mainnet.txt", deploymentInfo);
    }
}


