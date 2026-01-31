// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/WrappedToken.sol";

/**
 * @title WrappedTokenTest
 * @notice Unit tests for WrappedToken contract
 */
contract WrappedTokenTest is Test {
    // ============================================
    // STATE VARIABLES
    // ============================================

    WrappedToken public wToken;

    address public owner = address(1);
    address public bridge = address(2);
    address public user1 = address(3);
    address public user2 = address(4);

    // Original token info (simulating USDC from Ethereum)
    address public originalToken = address(100);
    uint256 public originalChainId = 1; // Ethereum
    uint8 public tokenDecimals = 6;

    // ============================================
    // SETUP
    // ============================================

    function setUp() public {
        vm.prank(owner);
        wToken = new WrappedToken(
            "Wrapped USDC",
            "wUSDC",
            tokenDecimals,
            originalToken,
            originalChainId,
            owner
        );

        // Set bridge address
        vm.prank(owner);
        wToken.setBridge(bridge);
    }

    // ============================================
    // CONSTRUCTOR TESTS
    // ============================================

    /**
     * @notice Test token is initialized correctly
     */
    function test_Constructor_SetsCorrectValues() public view {
        assertEq(wToken.name(), "Wrapped USDC");
        assertEq(wToken.symbol(), "wUSDC");
        assertEq(wToken.decimals(), 6);
        assertEq(wToken.originalToken(), originalToken);
        assertEq(wToken.originalChainId(), originalChainId);
        assertEq(wToken.owner(), owner);
    }

    // ============================================
    // MINT TESTS
    // ============================================

    /**
     * @notice Test bridge can mint tokens
     */
    function test_Mint_Success() public {
        uint256 mintAmount = 100e6; // 100 wUSDC

        vm.prank(bridge);
        wToken.mint(user1, mintAmount);

        assertEq(wToken.balanceOf(user1), mintAmount);
        assertEq(wToken.totalSupply(), mintAmount);
    }

    /**
     * @notice Test non-bridge cannot mint
     */
    function test_Mint_RevertIfNotBridge() public {
        vm.prank(user1);
        vm.expectRevert("Only bridge can call");
        wToken.mint(user1, 100e6);
    }

    /**
     * @notice Test cannot mint to zero address
     */
    function test_Mint_RevertIfZeroAddress() public {
        vm.prank(bridge);
        vm.expectRevert("Cannot mint to zero address");
        wToken.mint(address(0), 100e6);
    }

    /**
     * @notice Test cannot mint zero amount
     */
    function test_Mint_RevertIfZeroAmount() public {
        vm.prank(bridge);
        vm.expectRevert("Amount must be > 0");
        wToken.mint(user1, 0);
    }

    // ============================================
    // BURN FOR BRIDGE TESTS
    // ============================================

    /**
     * @notice Test user can burn tokens to bridge back
     */
    function test_BurnForBridge_Success() public {
        // First mint some tokens
        vm.prank(bridge);
        wToken.mint(user1, 100e6);

        // User burns to bridge back
        vm.prank(user1);
        wToken.burnForBridge(50e6, user1);

        // Check balances
        assertEq(wToken.balanceOf(user1), 50e6);
        assertEq(wToken.totalSupply(), 50e6);
        assertEq(wToken.burnNonce(), 1);
    }

    /**
     * @notice Test burn emits correct event
     */
    function test_BurnForBridge_EmitsEvent() public {
        // Mint first
        vm.prank(bridge);
        wToken.mint(user1, 100e6);

        // Expect burn event
        vm.expectEmit(true, true, true, true);
        emit WrappedToken.TokensBurned(
            user1, // burner
            50e6, // amount
            originalChainId, // destChainId (going back)
            user1, // recipient on source
            1 // nonce
        );

        vm.prank(user1);
        wToken.burnForBridge(50e6, user1);
    }

    /**
     * @notice Test cannot burn more than balance
     */
    function test_BurnForBridge_RevertIfInsufficientBalance() public {
        // Mint 100
        vm.prank(bridge);
        wToken.mint(user1, 100e6);

        // Try to burn 200
        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        wToken.burnForBridge(200e6, user1);
    }

    /**
     * @notice Test nonce increments correctly
     */
    function test_BurnForBridge_NonceIncrements() public {
        // Mint tokens
        vm.prank(bridge);
        wToken.mint(user1, 1000e6);

        // Burn 3 times
        vm.startPrank(user1);
        wToken.burnForBridge(100e6, user1);
        assertEq(wToken.burnNonce(), 1);

        wToken.burnForBridge(100e6, user1);
        assertEq(wToken.burnNonce(), 2);

        wToken.burnForBridge(100e6, user1);
        assertEq(wToken.burnNonce(), 3);
        vm.stopPrank();
    }

    // ============================================
    // ADMIN TESTS
    // ============================================

    /**
     * @notice Test owner can set bridge
     */
    function test_SetBridge_Success() public {
        address newBridge = address(99);

        vm.prank(owner);
        wToken.setBridge(newBridge);

        assertEq(wToken.bridge(), newBridge);
    }

    /**
     * @notice Test non-owner cannot set bridge
     */
    function test_SetBridge_RevertIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert(); // Ownable error
        wToken.setBridge(address(99));
    }

    /**
     * @notice Test cannot set zero address as bridge
     */
    function test_SetBridge_RevertIfZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid bridge address");
        wToken.setBridge(address(0));
    }

    // ============================================
    // VIEW FUNCTION TESTS
    // ============================================

    /**
     * @notice Test getTokenInfo returns correct data
     */
    function test_GetTokenInfo() public view {
        (
            string memory name,
            string memory symbol,
            uint8 decimals,
            address origToken,
            uint256 origChainId
        ) = wToken.getTokenInfo();

        assertEq(name, "Wrapped USDC");
        assertEq(symbol, "wUSDC");
        assertEq(decimals, 6);
        assertEq(origToken, originalToken);
        assertEq(origChainId, originalChainId);
    }

    // ============================================
    // ERC20 STANDARD TESTS
    // ============================================

    /**
     * @notice Test transfer works correctly
     */
    function test_Transfer_Success() public {
        // Mint to user1
        vm.prank(bridge);
        wToken.mint(user1, 100e6);

        // Transfer to user2
        vm.prank(user1);
        wToken.transfer(user2, 40e6);

        assertEq(wToken.balanceOf(user1), 60e6);
        assertEq(wToken.balanceOf(user2), 40e6);
    }

    /**
     * @notice Test approve and transferFrom
     */
    function test_ApproveAndTransferFrom_Success() public {
        // Mint to user1
        vm.prank(bridge);
        wToken.mint(user1, 100e6);

        // User1 approves user2
        vm.prank(user1);
        wToken.approve(user2, 50e6);

        // User2 transfers from user1
        vm.prank(user2);
        wToken.transferFrom(user1, user2, 50e6);

        assertEq(wToken.balanceOf(user1), 50e6);
        assertEq(wToken.balanceOf(user2), 50e6);
    }
}
