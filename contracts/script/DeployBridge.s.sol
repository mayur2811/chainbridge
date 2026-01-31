// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BridgeVault.sol";
import "../src/BridgeRouter.sol";
import "../src/WrappedToken.sol";
import "../src/ValidatorSet.sol";
import "../src/MessageVerifier.sol";

/**
 * @title DeployBridge
 * @notice Deploys all ChainBridge contracts to a network
 * 
 * Usage:
 * forge script script/DeployBridge.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
 */
contract DeployBridge is Script {
    function run() external {
        // Get deployer from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying from:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ValidatorSet
        address[] memory validators = new address[](1);
        validators[0] = deployer;  // Deployer is first validator
        
        ValidatorSet validatorSet = new ValidatorSet(
            deployer,     // owner
            validators,   // initial validators
            1             // threshold (1-of-1 for testing)
        );
        console.log("ValidatorSet deployed:", address(validatorSet));

        // 2. Deploy MessageVerifier
        MessageVerifier messageVerifier = new MessageVerifier(address(validatorSet));
        console.log("MessageVerifier deployed:", address(messageVerifier));

        // 3. Deploy BridgeVault
        BridgeVault vault = new BridgeVault(deployer);
        console.log("BridgeVault deployed:", address(vault));

        // 4. Deploy BridgeRouter
        BridgeRouter router = new BridgeRouter(deployer, address(vault));
        console.log("BridgeRouter deployed:", address(router));

        // 5. Configure Vault
        vault.addValidator(deployer);
        vault.addValidator(address(router));
        console.log("Vault configured with validators");

        // 6. Configure Router
        router.addValidator(deployer);
        // Add Arbitrum Sepolia as supported chain
        router.setSupportedChain(421614, true);
        console.log("Router configured");

        vm.stopBroadcast();

        console.log("");
        console.log("========================================");
        console.log("DEPLOYMENT COMPLETE!");
        console.log("========================================");
        console.log("");
        console.log("Save these addresses:");
        console.log("  ValidatorSet:", address(validatorSet));
        console.log("  MessageVerifier:", address(messageVerifier));
        console.log("  BridgeVault:", address(vault));
        console.log("  BridgeRouter:", address(router));
    }
}
