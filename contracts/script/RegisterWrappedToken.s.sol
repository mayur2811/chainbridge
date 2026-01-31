// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BridgeRouter.sol";
import "../src/WrappedToken.sol";

/**
 * @title RegisterWrappedToken
 * @notice Deploy and register a wrapped token on Hoodi for the test token on Sepolia
 */
contract RegisterWrappedToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Address of test token deployed on Sepolia
        address originalTokenOnSepolia = 0x9f76259FF348362e23753815d351c5F4177b77B7;
        uint256 sepoliaChainId = 11155111;
        
        // BridgeRouter on Hoodi
        address routerAddress = 0xcF1C4C9ad85185ae346F71beCae1A92a41d857f5;
        
        console.log("Deploying wrapped token on Hoodi...");
        console.log("Original token (Sepolia):", originalTokenOnSepolia);
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy WrappedToken on Hoodi
        // Constructor: name, symbol, decimals, originalToken, originalChainId, initialOwner
        WrappedToken wrappedToken = new WrappedToken(
            "Wrapped Test Token",
            "wTEST",
            18, // decimals
            originalTokenOnSepolia,
            sepoliaChainId,
            deployer // initialOwner
        );
        console.log("WrappedToken deployed at:", address(wrappedToken));
        
        // 2. Register the wrapped token in the router
        BridgeRouter router = BridgeRouter(routerAddress);
        router.registerWrappedToken(originalTokenOnSepolia, address(wrappedToken));
        console.log("Wrapped token registered in router");
        
        // 3. Set the router as the bridge (so it can mint)
        wrappedToken.setBridge(routerAddress);
        console.log("Router set as bridge (can mint tokens)");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("========================================");
        console.log("WRAPPED TOKEN SETUP COMPLETE!");
        console.log("========================================");
        console.log("Original Token (Sepolia):", originalTokenOnSepolia);
        console.log("Wrapped Token (Hoodi):", address(wrappedToken));
        console.log("");
        console.log("Now try the bridge again!");
    }
}
