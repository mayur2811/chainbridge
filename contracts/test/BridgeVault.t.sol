// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BridgeVault.sol";
import "./mocks/MockERC20.sol";

/**
 * @title BridgeVaultTest
 * @notice Unit tests for BridgeVault contract
 *
 * TEST STRUCTURE:
 * - setUp() runs BEFORE each test
 * - Each test_* function is an independent test
 * - We test: normal flows, edge cases, and failures
 */
contract BridgeVaultTest is Test {
    // ============================================
    // STATE VARIABLES
    // ============================================

    BridgeVault public vault;
    MockERC20 public usdc;
    MockERC20 public weth;

    // Test addresses
    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public validator = address(4);

    // Test values
    uint256 public constant INITIAL_BALANCE = 10000e6; // 10,000 USDC (6 decimals)
    uint256 public constant MIN_BRIDGE_AMOUNT = 10e6; // 10 USDC minimum
    uint256 public constant DEST_CHAIN_ID = 42161; // Arbitrum

    // ============================================
    // SETUP - Runs before each test
    // ============================================

    function setUp() public {
        // Deploy as owner
        vm.startPrank(owner);

        // Deploy vault
        vault = new BridgeVault(owner);

        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);

        // Add USDC as supported token
        vault.addSupportedToken(address(usdc), MIN_BRIDGE_AMOUNT);

        // Add validator
        vault.addValidator(validator);

        vm.stopPrank();

        // Give user1 some USDC
        usdc.mint(user1, INITIAL_BALANCE);
    }

    // ============================================
    // LOCK TOKENS TESTS
    // ============================================

    /**
     * @notice Test successful token locking
     * FLOW: User approves → User locks → Tokens in vault
     */
    function test_LockTokens_Success() public {
        uint256 lockAmount = 100e6; // 100 USDC

        // User1 approves vault to spend tokens
        vm.startPrank(user1);
        usdc.approve(address(vault), lockAmount);

        // User1 locks tokens
        vault.lockTokens(
            address(usdc),
            lockAmount,
            DEST_CHAIN_ID,
            user1 // recipient on destination
        );
        vm.stopPrank();

        // ASSERTIONS
        // 1. User balance decreased
        assertEq(usdc.balanceOf(user1), INITIAL_BALANCE - lockAmount);

        // 2. Vault balance increased
        assertEq(usdc.balanceOf(address(vault)), lockAmount);

        // 3. Nonce increased
        assertEq(vault.nonce(), 1);

        // 4. Lock info stored correctly
        (
            address sender,
            address token,
            uint256 amount,
            uint256 timestamp,
            bool completed,
            bool withdrawn
        ) = vault.lockInfo(1);

        assertEq(sender, user1);
        assertEq(token, address(usdc));
        assertEq(amount, lockAmount);
        assertTrue(timestamp > 0);
        assertFalse(completed);
        assertFalse(withdrawn);
    }

    /**
     * @notice Test locking emits correct event
     */
    function test_LockTokens_EmitsEvent() public {
        uint256 lockAmount = 100e6;

        vm.startPrank(user1);
        usdc.approve(address(vault), lockAmount);

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit BridgeVault.TokensLocked(
            user1,
            address(usdc),
            lockAmount,
            DEST_CHAIN_ID,
            user1,
            1 // First nonce
        );

        vault.lockTokens(address(usdc), lockAmount, DEST_CHAIN_ID, user1);
        vm.stopPrank();
    }

    /**
     * @notice Test: Cannot lock unsupported token
     */
    function test_LockTokens_RevertIfUnsupportedToken() public {
        vm.startPrank(user1);
        weth.mint(user1, 1e18);
        weth.approve(address(vault), 1e18);

        vm.expectRevert("Token not supported");
        vault.lockTokens(address(weth), 1e18, DEST_CHAIN_ID, user1);
        vm.stopPrank();
    }

    /**
     * @notice Test: Cannot lock below minimum amount
     */
    function test_LockTokens_RevertIfBelowMinimum() public {
        uint256 tooSmall = MIN_BRIDGE_AMOUNT - 1;

        vm.startPrank(user1);
        usdc.approve(address(vault), tooSmall);

        vm.expectRevert("Amount below minimum");
        vault.lockTokens(address(usdc), tooSmall, DEST_CHAIN_ID, user1);
        vm.stopPrank();
    }

    /**
     * @notice Test: Cannot lock to zero address recipient
     */
    function test_LockTokens_RevertIfInvalidRecipient() public {
        vm.startPrank(user1);
        usdc.approve(address(vault), 100e6);

        vm.expectRevert("Invalid recipient");
        vault.lockTokens(address(usdc), 100e6, DEST_CHAIN_ID, address(0));
        vm.stopPrank();
    }

    /**
     * @notice Test: Cannot lock to same chain
     */
    function test_LockTokens_RevertIfSameChain() public {
        vm.startPrank(user1);
        usdc.approve(address(vault), 100e6);

        vm.expectRevert("Cannot bridge to same chain");
        vault.lockTokens(address(usdc), 100e6, block.chainid, user1);
        vm.stopPrank();
    }

    // ============================================
    // RELEASE TOKENS TESTS
    // ============================================

    /**
     * @notice Test: Validator can release tokens
     */
    function test_ReleaseTokens_Success() public {
        // First, lock some tokens
        uint256 lockAmount = 100e6;
        vm.startPrank(user1);
        usdc.approve(address(vault), lockAmount);
        vault.lockTokens(address(usdc), lockAmount, DEST_CHAIN_ID, user1);
        vm.stopPrank();

        // Record user2 balance before
        uint256 balanceBefore = usdc.balanceOf(user2);

        // Validator releases to user2
        vm.prank(validator);
        vault.releaseTokens(
            address(usdc),
            user2,
            lockAmount,
            DEST_CHAIN_ID,
            1 // source nonce
        );

        // ASSERTIONS
        // 1. User2 received tokens
        assertEq(usdc.balanceOf(user2), balanceBefore + lockAmount);

        // 2. Vault balance decreased
        assertEq(usdc.balanceOf(address(vault)), 0);

        // 3. Nonce marked as processed
        assertTrue(vault.processedNonces(1));
    }

    /**
     * @notice Test: Non-validator cannot release tokens
     */
    function test_ReleaseTokens_RevertIfNotValidator() public {
        // Lock tokens first
        vm.startPrank(user1);
        usdc.approve(address(vault), 100e6);
        vault.lockTokens(address(usdc), 100e6, DEST_CHAIN_ID, user1);
        vm.stopPrank();

        // Random user tries to release
        vm.prank(user2);
        vm.expectRevert("Not a validator");
        vault.releaseTokens(address(usdc), user2, 100e6, DEST_CHAIN_ID, 1);
    }

    /**
     * @notice Test: Cannot release same nonce twice
     */
    function test_ReleaseTokens_RevertIfAlreadyProcessed() public {
        // Lock tokens
        vm.startPrank(user1);
        usdc.approve(address(vault), 200e6);
        vault.lockTokens(address(usdc), 200e6, DEST_CHAIN_ID, user1);
        vm.stopPrank();

        // First release - success
        vm.prank(validator);
        vault.releaseTokens(address(usdc), user2, 100e6, DEST_CHAIN_ID, 1);

        // Second release same nonce - fail
        vm.prank(validator);
        vm.expectRevert("Already processed");
        vault.releaseTokens(address(usdc), user2, 100e6, DEST_CHAIN_ID, 1);
    }

    // ============================================
    // EMERGENCY WITHDRAWAL TESTS
    // ============================================

    /**
     * @notice Test: User can emergency withdraw after delay
     */
    function test_EmergencyWithdraw_Success() public {
        uint256 lockAmount = 100e6;

        // Lock tokens
        vm.startPrank(user1);
        usdc.approve(address(vault), lockAmount);
        vault.lockTokens(address(usdc), lockAmount, DEST_CHAIN_ID, user1);
        vm.stopPrank();

        // Fast forward 7 days
        vm.warp(block.timestamp + 7 days + 1);

        // Emergency withdraw
        uint256 balanceBefore = usdc.balanceOf(user1);
        vm.prank(user1);
        vault.emergencyWithdraw(1);

        // ASSERTIONS
        // 1. User got tokens back
        assertEq(usdc.balanceOf(user1), balanceBefore + lockAmount);

        // 2. Lock marked as withdrawn
        (, , , , , bool withdrawn) = vault.lockInfo(1);
        assertTrue(withdrawn);
    }

    /**
     * @notice Test: Cannot emergency withdraw before delay
     */
    function test_EmergencyWithdraw_RevertIfTooEarly() public {
        // Lock tokens
        vm.startPrank(user1);
        usdc.approve(address(vault), 100e6);
        vault.lockTokens(address(usdc), 100e6, DEST_CHAIN_ID, user1);

        // Try immediately
        vm.expectRevert("Too early - wait for delay period");
        vault.emergencyWithdraw(1);
        vm.stopPrank();
    }

    /**
     * @notice Test: Cannot emergency withdraw if bridge completed
     */
    function test_EmergencyWithdraw_RevertIfCompleted() public {
        // Lock tokens
        vm.startPrank(user1);
        usdc.approve(address(vault), 100e6);
        vault.lockTokens(address(usdc), 100e6, DEST_CHAIN_ID, user1);
        vm.stopPrank();

        // Validator marks as completed
        vm.prank(validator);
        vault.markBridgeCompleted(1);

        // Fast forward
        vm.warp(block.timestamp + 7 days + 1);

        // Try to withdraw
        vm.prank(user1);
        vm.expectRevert("Bridge was completed - cannot withdraw");
        vault.emergencyWithdraw(1);
    }

    /**
     * @notice Test: Cannot emergency withdraw someone else's lock
     */
    function test_EmergencyWithdraw_RevertIfNotOwner() public {
        // User1 locks tokens
        vm.startPrank(user1);
        usdc.approve(address(vault), 100e6);
        vault.lockTokens(address(usdc), 100e6, DEST_CHAIN_ID, user1);
        vm.stopPrank();

        // Fast forward
        vm.warp(block.timestamp + 7 days + 1);

        // User2 tries to withdraw user1's lock
        vm.prank(user2);
        vm.expectRevert("Not your lock");
        vault.emergencyWithdraw(1);
    }

    // ============================================
    // ADMIN TESTS
    // ============================================

    /**
     * @notice Test: Owner can add supported token
     */
    function test_AddSupportedToken() public {
        vm.prank(owner);
        vault.addSupportedToken(address(weth), 0.01e18);

        assertTrue(vault.supportedTokens(address(weth)));
        assertEq(vault.minBridgeAmount(address(weth)), 0.01e18);
    }

    /**
     * @notice Test: Owner can pause/unpause
     */
    function test_PauseAndUnpause() public {
        // Pause
        vm.prank(owner);
        vault.pause();

        // Try to lock while paused
        vm.startPrank(user1);
        usdc.approve(address(vault), 100e6);
        vm.expectRevert(); // Pausable: paused
        vault.lockTokens(address(usdc), 100e6, DEST_CHAIN_ID, user1);
        vm.stopPrank();

        // Unpause
        vm.prank(owner);
        vault.unpause();

        // Now lock should work
        vm.startPrank(user1);
        vault.lockTokens(address(usdc), 100e6, DEST_CHAIN_ID, user1);
        vm.stopPrank();

        assertEq(vault.nonce(), 1);
    }

    /**
     * @notice Test: Non-owner cannot add token
     */
    function test_AddSupportedToken_RevertIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert(); // Ownable: caller is not the owner
        vault.addSupportedToken(address(weth), 0.01e18);
    }
}
