// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/WrappedToken.sol";

/**
 * @title TestReverseBridge
 * @notice Burn wrapped tokens on Hoodi to test reverse bridge flow
 */
contract TestReverseBridge is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // wTEST token on Hoodi (from RegisterWrappedToken deployment)
        address wrappedTokenAddress = 0xabB81B91BE2B922E6059844ed844D5660b41A75f;

        console.log("Testing REVERSE bridge (Hoodi -> Sepolia)...");
        console.log("Deployer:", deployer);
        console.log("Wrapped Token:", wrappedTokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        WrappedToken wrappedToken = WrappedToken(wrappedTokenAddress);

        // Check balance
        uint256 balance = wrappedToken.balanceOf(deployer);
        console.log("wTEST Balance:", balance / 1e18);

        require(balance >= 5 ether, "Not enough wTEST to burn");

        // Burn tokens to bridge back to Sepolia
        wrappedToken.burnForBridge(5 ether, deployer);
        console.log("SUCCESS! Burned 5 wTEST to bridge back to Sepolia");

        uint256 burnNonce = wrappedToken.burnNonce();
        console.log("Burn nonce:", burnNonce);

        vm.stopBroadcast();

        console.log("");
        console.log("========================================");
        console.log("REVERSE BRIDGE TEST!");
        console.log("========================================");
        console.log("Burned: 5 wTEST on Hoodi");
        console.log("Expecting: 5 TEST released on Sepolia");
        console.log("Burn Nonce:", burnNonce);
    }
}
