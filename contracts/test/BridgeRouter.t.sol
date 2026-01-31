// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BridgeRouter.sol";
import "../src/BridgeVault.sol";
import "../src/WrappedToken.sol";
import "./mocks/MockERC20.sol";

/**
 * @title BridgeRouterTest
 * @notice Integration tests for BridgeRouter contract
 * Tests the full bridge flow end-to-end
 */
contract BridgeRouterTest is Test {
    // ============================================
    // STATE VARIABLES
    // ============================================

    BridgeRouter public router;
    BridgeVault public vault;
    WrappedToken public wToken;
    MockERC20 public usdc;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public validator = address(4);

    uint256 public constant INITIAL_BALANCE = 10000e6;
    uint256 public constant DEST_CHAIN_ID = 42161;
    uint256 public constant SOURCE_CHAIN_ID = 1;

    // ============================================
    // SETUP
    // ============================================

    function setUp() public {
        vm.startPrank(owner);

        // Deploy vault
        vault = new BridgeVault(owner);

        // Deploy mock USDC
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy router
        router = new BridgeRouter(owner, address(vault));

        // Deploy wrapped token
        wToken = new WrappedToken(
            "Wrapped USDC",
            "wUSDC",
            6,
            address(usdc),
            SOURCE_CHAIN_ID,
            owner
        );

        // Configure vault
        vault.addSupportedToken(address(usdc), 10e6);
        vault.addValidator(validator);
        vault.addValidator(address(router));

        // Configure router
        router.setSupportedChain(DEST_CHAIN_ID, true);
        router.addValidator(validator);
        router.registerWrappedToken(address(usdc), address(wToken));

        // Configure wrapped token
        wToken.setBridge(address(router));

        vm.stopPrank();

        // Give user tokens
        usdc.mint(user1, INITIAL_BALANCE);
    }

    // ============================================
    // BRIDGE INITIATION TESTS
    // ============================================

    /**
     * @notice Test successful bridge initiation
     */
    function test_Bridge_Success() public {
        uint256 bridgeAmount = 100e6;

        vm.startPrank(user1);
        usdc.approve(address(router), bridgeAmount);

        uint256 nonce = router.bridge(
            address(usdc),
            bridgeAmount,
            DEST_CHAIN_ID,
            user1
        );
        vm.stopPrank();

        // Assertions
        assertEq(nonce, 1);
        assertEq(usdc.balanceOf(user1), INITIAL_BALANCE - bridgeAmount);
        assertEq(usdc.balanceOf(address(vault)), bridgeAmount);
    }

    /**
     * @notice Test bridge emits correct event
     */
    function test_Bridge_EmitsEvent() public {
        uint256 bridgeAmount = 100e6;

        vm.startPrank(user1);
        usdc.approve(address(router), bridgeAmount);

        vm.expectEmit(true, true, true, true);
        emit BridgeRouter.BridgeInitiated(
            user1,
            address(usdc),
            bridgeAmount,
            DEST_CHAIN_ID,
            user1,
            1
        );

        router.bridge(address(usdc), bridgeAmount, DEST_CHAIN_ID, user1);
        vm.stopPrank();
    }

    /**
     * @notice Test bridge fails for unsupported chain
     */
    function test_Bridge_RevertIfUnsupportedChain() public {
        vm.startPrank(user1);
        usdc.approve(address(router), 100e6);

        vm.expectRevert("Destination chain not supported");
        router.bridge(address(usdc), 100e6, 999, user1); // Unsupported chain
        vm.stopPrank();
    }

    /**
     * @notice Test bridge fails when paused
     */
    function test_Bridge_RevertWhenPaused() public {
        vm.prank(owner);
        router.pause();

        vm.startPrank(user1);
        usdc.approve(address(router), 100e6);

        vm.expectRevert(); // Pausable: paused
        router.bridge(address(usdc), 100e6, DEST_CHAIN_ID, user1);
        vm.stopPrank();
    }

    // ============================================
    // COMPLETE BRIDGE TESTS (Minting)
    // ============================================

    /**
     * @notice Test validator can complete bridge (mint tokens)
     */
    function test_CompleteBridge_Success() public {
        uint256 amount = 100e6;

        // Complete bridge (validator mints wrapped tokens)
        vm.prank(validator);
        router.completeBridge(
            address(usdc),
            user2,
            amount,
            SOURCE_CHAIN_ID,
            1 // nonce
        );

        // User2 should have wrapped tokens
        assertEq(wToken.balanceOf(user2), amount);
    }

    /**
     * @notice Test non-validator cannot complete bridge
     */
    function test_CompleteBridge_RevertIfNotValidator() public {
        vm.prank(user1);
        vm.expectRevert("Not a validator");
        router.completeBridge(address(usdc), user2, 100e6, SOURCE_CHAIN_ID, 1);
    }

    /**
     * @notice Test cannot complete same message twice
     */
    function test_CompleteBridge_RevertIfAlreadyProcessed() public {
        // First completion
        vm.prank(validator);
        router.completeBridge(address(usdc), user2, 100e6, SOURCE_CHAIN_ID, 1);

        // Second attempt with same message
        vm.prank(validator);
        vm.expectRevert("Already processed");
        router.completeBridge(address(usdc), user2, 100e6, SOURCE_CHAIN_ID, 1);
    }

    // ============================================
    // RELEASE BRIDGE TESTS
    // ============================================

    /**
     * @notice Test validator can release tokens
     */
    function test_ReleaseBridge_Success() public {
        // First lock some tokens
        vm.startPrank(user1);
        usdc.approve(address(router), 100e6);
        router.bridge(address(usdc), 100e6, DEST_CHAIN_ID, user1);
        vm.stopPrank();

        // Release to user2
        vm.prank(validator);
        router.releaseBridge(
            address(usdc),
            user2,
            100e6,
            DEST_CHAIN_ID,
            1 // nonce
        );

        assertEq(usdc.balanceOf(user2), 100e6);
    }

    // ============================================
    // ADMIN TESTS
    // ============================================

    /**
     * @notice Test owner can add supported chain
     */
    function test_SetSupportedChain_Success() public {
        uint256 newChainId = 8453; // Base

        vm.prank(owner);
        router.setSupportedChain(newChainId, true);

        assertTrue(router.supportedChains(newChainId));
    }

    /**
     * @notice Test owner can register wrapped token
     */
    function test_RegisterWrappedToken_Success() public {
        address newToken = address(500);
        WrappedToken newWrapped = new WrappedToken(
            "Wrapped ETH",
            "wETH",
            18,
            newToken,
            1,
            owner
        );

        vm.prank(owner);
        router.registerWrappedToken(newToken, address(newWrapped));

        assertEq(address(router.wrappedTokens(newToken)), address(newWrapped));
    }

    /**
     * @notice Test non-owner cannot add chain
     */
    function test_SetSupportedChain_RevertIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert(); // Ownable error
        router.setSupportedChain(8453, true);
    }

    /**
     * @notice Test pause and unpause
     */
    function test_PauseUnpause() public {
        // Pause
        vm.prank(owner);
        router.pause();

        // Verify paused
        vm.startPrank(user1);
        usdc.approve(address(router), 100e6);
        vm.expectRevert();
        router.bridge(address(usdc), 100e6, DEST_CHAIN_ID, user1);
        vm.stopPrank();

        // Unpause
        vm.prank(owner);
        router.unpause();

        // Should work now
        vm.startPrank(user1);
        router.bridge(address(usdc), 100e6, DEST_CHAIN_ID, user1);
        vm.stopPrank();

        assertEq(vault.nonce(), 1);
    }

    // ============================================
    // FULL FLOW INTEGRATION TEST
    // ============================================

    /**
     * @notice Test complete bridge flow: lock → mint → burn → release
     */
    function test_FullBridgeFlow() public {
        uint256 amount = 100e6;

        // === STEP 1: User locks tokens on source chain ===
        vm.startPrank(user1);
        usdc.approve(address(router), amount);
        uint256 lockNonce = router.bridge(
            address(usdc),
            amount,
            DEST_CHAIN_ID,
            user1
        );
        vm.stopPrank();

        assertEq(lockNonce, 1);
        assertEq(usdc.balanceOf(address(vault)), amount);

        // === STEP 2: Validator mints wrapped tokens on dest chain ===
        vm.prank(validator);
        router.completeBridge(address(usdc), user1, amount, SOURCE_CHAIN_ID, 1);

        assertEq(wToken.balanceOf(user1), amount);

        // === STEP 3: User burns wrapped tokens to bridge back ===
        vm.prank(user1);
        wToken.burnForBridge(amount, user1);

        assertEq(wToken.balanceOf(user1), 0);
        assertEq(wToken.burnNonce(), 1);

        // === STEP 4: Validator releases original tokens ===
        vm.prank(validator);
        router.releaseBridge(address(usdc), user1, amount, DEST_CHAIN_ID, 1);

        assertEq(usdc.balanceOf(user1), INITIAL_BALANCE);
        assertEq(usdc.balanceOf(address(vault)), 0);
    }
}
