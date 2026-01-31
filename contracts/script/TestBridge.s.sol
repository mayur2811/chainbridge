// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BridgeVault.sol";
import "../src/BridgeRouter.sol";
import "../test/mocks/MockERC20.sol";

/**
 * @title TestBridge
 * @notice Script to test the bridge by deploying a test token and locking it
 */
contract TestBridge is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Deployed contract addresses (Sepolia)
        address vaultAddress = 0xcD54697e22264a0c496606301ae19421c690f3dc;
        address routerAddress = 0xcF1C4C9ad85185ae346F71beCae1A92a41d857f5;
        
        console.log("Testing bridge from:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy a test token
        MockERC20 testToken = new MockERC20("Test Token", "TEST", 18);
        console.log("Test Token deployed:", address(testToken));
        
        // 2. Mint some tokens to deployer
        testToken.mint(deployer, 1000 ether);
        console.log("Minted 1000 TEST tokens to deployer");
        
        // 3. Get vault and router contracts
        BridgeVault vault = BridgeVault(vaultAddress);
        BridgeRouter router = BridgeRouter(routerAddress);
        
        // 4. Add token as supported in vault (owner only)
        vault.addSupportedToken(address(testToken), 1 ether); // Min 1 token
        console.log("Token added to vault as supported");
        
        // 5. Approve vault to spend tokens
        testToken.approve(address(vault), 100 ether);
        console.log("Approved vault to spend 100 TEST");
        
        // 6. Lock tokens (bridge to Hoodi - chain ID 560048)
        vault.lockTokens(address(testToken), 10 ether, 560048, deployer);
        console.log("SUCCESS! Locked 10 TEST tokens to bridge to Hoodi");
        
        // Get the lock nonce
        uint256 nonce = vault.nonce();
        console.log("Lock nonce:", nonce);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("========================================");
        console.log("BRIDGE TEST SUCCESSFUL!");
        console.log("========================================");
        console.log("Test Token:", address(testToken));
        console.log("Amount locked: 10 TEST");
        console.log("Destination: Hoodi (560048)");
        console.log("Lock Nonce:", nonce);
        console.log("");
        console.log("Next step: Run the relayer to complete the bridge on Hoodi!");
    }
}
