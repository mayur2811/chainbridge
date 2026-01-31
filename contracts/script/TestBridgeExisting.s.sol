// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BridgeVault.sol";
import "../test/mocks/MockERC20.sol";

/**
 * @title TestBridgeExisting
 * @notice Lock tokens using the EXISTING test token that has wrapped token registered
 */
contract TestBridgeExisting is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Deployed contract addresses (Sepolia)
        address vaultAddress = 0xcD54697e22264a0c496606301ae19421c690f3dc;

        // EXISTING test token - this one has wrapped token registered on Hoodi
        address testTokenAddress = 0x9f76259FF348362e23753815d351c5F4177b77B7;

        console.log("Testing bridge with EXISTING token...");
        console.log("Deployer:", deployer);
        console.log("Test Token:", testTokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        MockERC20 testToken = MockERC20(testTokenAddress);
        BridgeVault vault = BridgeVault(vaultAddress);

        // Mint more tokens
        testToken.mint(deployer, 100 ether);
        console.log("Minted 100 TEST tokens");

        // Approve vault
        testToken.approve(address(vault), 100 ether);
        console.log("Approved vault");

        // Lock tokens (bridge to Hoodi)
        vault.lockTokens(address(testToken), 10 ether, 560048, deployer);
        console.log("SUCCESS! Locked 10 TEST tokens to bridge to Hoodi");

        uint256 nonce = vault.nonce();
        console.log("Lock nonce:", nonce);

        vm.stopBroadcast();

        console.log("");
        console.log("========================================");
        console.log("BRIDGE TEST WITH EXISTING TOKEN!");
        console.log("========================================");
        console.log("Token:", testTokenAddress);
        console.log("Amount: 10 TEST");
        console.log("Destination: Hoodi (560048)");
        console.log("Nonce:", nonce);
    }
}
