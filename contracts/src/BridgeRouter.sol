// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================
// IMPORTS
// ============================================

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Import our contracts
import "./BridgeVault.sol";
import "./WrappedToken.sol";

/**
 * @title BridgeRouter
 * @notice Main entry point for users to bridge tokens
 * @dev Coordinates between BridgeVault and WrappedToken contracts
 *
 * WHY THIS CONTRACT EXISTS:
 * Without router, users would need to:
 * 1. Know vault address, wrapped token addresses
 * 2. Call multiple contracts in correct order
 * 3. Handle all the complexity themselves
 *
 * With router, users just call:
 * router.bridge(token, amount, destChain) - Done! ✅
 *
 * DEPLOYMENT:
 * - Deploy on EACH chain (Ethereum, Arbitrum, Base, etc.)
 * - Each chain has its own router
 */
contract BridgeRouter is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    // ============================================
    // STATE VARIABLES
    // ============================================

    /**
     * @notice The vault contract that locks tokens
     * @dev Only used on SOURCE chains (where original tokens live)
     * On Ethereum: vault holds locked USDC, WETH, etc.
     */
    BridgeVault public vault;

    /**
     * @notice Maps original token → wrapped token on this chain
     * @dev Example on Arbitrum:
     * wrappedTokens[USDC_Ethereum] = wUSDC_Arbitrum
     *
     * This tells router: "When bridging USDC from Ethereum,
     * mint wUSDC on Arbitrum"
     */
    mapping(address => WrappedToken) public wrappedTokens;

    /**
     * @notice Maps destination chain → whether it's supported
     * @dev supportedChains[42161] = true means we can bridge TO Arbitrum
     */
    mapping(uint256 => bool) public supportedChains;

    /**
     * @notice Trusted validators who can complete bridge operations
     * @dev Only these addresses can call completeBridge() and releaseBridge()
     */
    mapping(address => bool) public validators;

    /**
     * @notice Track processed bridge messages (prevent replay)
     * @dev Key = keccak256(sourceChain, nonce)
     */
    mapping(bytes32 => bool) public processedMessages;

    /**
     * @notice This chain's ID
     * @dev Set at deployment, used for validation
     */
    uint256 public immutable chainId;

    // ============================================
    // EVENTS
    // ============================================

    /**
     * @notice Emitted when user initiates a bridge
     * @dev Relayers watch this to complete bridge on destination
     */
    event BridgeInitiated(
        address indexed sender,
        address indexed token,
        uint256 amount,
        uint256 indexed destChainId,
        address recipient,
        uint256 nonce
    );

    /**
     * @notice Emitted when bridge is completed (tokens minted)
     */
    event BridgeCompleted(
        address indexed recipient,
        address indexed wrappedToken,
        uint256 amount,
        uint256 sourceChainId,
        uint256 nonce
    );

    /**
     * @notice Emitted when original tokens are released (bridging back)
     */
    event BridgeReleased(
        address indexed recipient,
        address indexed token,
        uint256 amount,
        uint256 sourceChainId,
        uint256 nonce
    );

    // Admin events
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event WrappedTokenRegistered(
        address indexed originalToken,
        address indexed wrappedToken
    );
    event ChainSupported(uint256 indexed chainId, bool supported);

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /**
     * @notice Deploy the router
     * @param initialOwner Admin address
     * @param _vault The vault contract (can be address(0) on destination chains)
     *
     * DEPLOYMENT EXAMPLES:
     *
     * On Ethereum (source chain):
     * new BridgeRouter(admin, vaultAddress)
     *
     * On Arbitrum (destination chain):
     * new BridgeRouter(admin, address(0))  // No vault needed
     */
    constructor(address initialOwner, address _vault) Ownable(initialOwner) {
        chainId = block.chainid;

        // Vault is optional (only needed on source chains)
        if (_vault != address(0)) {
            vault = BridgeVault(_vault);
        }
    }

    // ============================================
    // MODIFIERS
    // ============================================

    modifier onlyValidator() {
        require(validators[msg.sender], "Not a validator");
        _;
    }

    // ============================================
    // USER FUNCTIONS
    // ============================================

    /**
     * @notice Bridge tokens to another chain
     * @param token The token to bridge (e.g., USDC address)
     * @param amount How many tokens to bridge
     * @param destChainId Destination chain ID (e.g., 42161 for Arbitrum)
     * @param recipient Who receives on destination (usually same as sender)
     *
     * BEFORE CALLING:
     * User must approve this router to spend their tokens!
     * Example: USDC.approve(routerAddress, amount)
     *
     * FLOW:
     * 1. User approves router
     * 2. User calls bridge()
     * 3. Router locks tokens in vault
     * 4. Event emitted
     * 5. Relayer completes on destination
     */
    function bridge(
        address token,
        uint256 amount,
        uint256 destChainId,
        address recipient
    ) external nonReentrant whenNotPaused returns (uint256 nonce) {
        // CHECKS
        require(amount > 0, "Amount must be > 0");
        require(recipient != address(0), "Invalid recipient");
        require(
            supportedChains[destChainId],
            "Destination chain not supported"
        );
        require(destChainId != chainId, "Cannot bridge to same chain");
        require(address(vault) != address(0), "Vault not set");

        // Transfer tokens from user to this router first
        // (Router will then send to vault)
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Approve vault to take tokens from router
        IERC20(token).approve(address(vault), amount);

        // Lock tokens in vault
        vault.lockTokens(token, amount, destChainId, recipient);

        // Get the nonce from vault (it just incremented)
        nonce = vault.nonce();

        emit BridgeInitiated(
            msg.sender,
            token,
            amount,
            destChainId,
            recipient,
            nonce
        );

        return nonce;
    }

    // ============================================
    // VALIDATOR FUNCTIONS
    // ============================================

    /**
     * @notice Complete a bridge by minting wrapped tokens
     * @param originalToken The original token address on source chain
     * @param recipient Who receives the wrapped tokens
     * @param amount How many tokens to mint
     * @param sourceChainId Which chain the tokens came from
     * @param nonce The unique ID from the source chain lock
     *
     * ONLY VALIDATORS CAN CALL!
     *
     * Called when:
     * 1. User locked tokens on source chain
     * 2. Relayer verified the lock event
     * 3. Validator calls this to mint wrapped tokens
     */
    function completeBridge(
        address originalToken,
        address recipient,
        uint256 amount,
        uint256 sourceChainId,
        uint256 nonce
    ) external onlyValidator nonReentrant whenNotPaused {
        // Create unique message ID
        bytes32 messageId = keccak256(abi.encodePacked(sourceChainId, nonce));

        // Check not already processed (prevent replay!)
        require(!processedMessages[messageId], "Already processed");
        processedMessages[messageId] = true;

        // Get the wrapped token for this original token
        WrappedToken wrappedToken = wrappedTokens[originalToken];
        require(
            address(wrappedToken) != address(0),
            "Wrapped token not registered"
        );

        // Mint wrapped tokens to recipient
        wrappedToken.mint(recipient, amount);

        emit BridgeCompleted(
            recipient,
            address(wrappedToken),
            amount,
            sourceChainId,
            nonce
        );
    }

    /**
     * @notice Release original tokens when bridging back
     * @param token The original token to release
     * @param recipient Who receives the tokens
     * @param amount How many tokens to release
     * @param sourceChainId Which chain the burn happened on
     * @param nonce The burn nonce from wrapped token
     *
     * ONLY VALIDATORS CAN CALL!
     *
     * Called when:
     * 1. User burned wrapped tokens on destination chain
     * 2. Relayer verified the burn event
     * 3. Validator calls this to release original tokens
     */
    function releaseBridge(
        address token,
        address recipient,
        uint256 amount,
        uint256 sourceChainId,
        uint256 nonce
    ) external onlyValidator nonReentrant whenNotPaused {
        // Create unique message ID
        bytes32 messageId = keccak256(abi.encodePacked(sourceChainId, nonce));

        // Check not already processed
        require(!processedMessages[messageId], "Already processed");
        processedMessages[messageId] = true;

        // Release tokens from vault
        require(address(vault) != address(0), "Vault not set");
        vault.releaseTokens(token, recipient, amount, sourceChainId, nonce);

        emit BridgeReleased(recipient, token, amount, sourceChainId, nonce);
    }

    // ============================================
    // ADMIN FUNCTIONS
    // ============================================

    /**
     * @notice Register a wrapped token for an original token
     * @param originalToken The token on source chain
     * @param wrappedToken The wrapped version on this chain
     *
     * Example on Arbitrum:
     * registerWrappedToken(USDC_Ethereum, wUSDC_Arbitrum)
     */
    function registerWrappedToken(
        address originalToken,
        address wrappedToken
    ) external onlyOwner {
        require(originalToken != address(0), "Invalid original token");
        require(wrappedToken != address(0), "Invalid wrapped token");

        wrappedTokens[originalToken] = WrappedToken(wrappedToken);
        emit WrappedTokenRegistered(originalToken, wrappedToken);
    }

    /**
     * @notice Add or remove support for a destination chain
     */
    function setSupportedChain(
        uint256 _chainId,
        bool supported
    ) external onlyOwner {
        supportedChains[_chainId] = supported;
        emit ChainSupported(_chainId, supported);
    }

    /**
     * @notice Add a validator
     */
    function addValidator(address validator) external onlyOwner {
        require(validator != address(0), "Invalid validator");
        validators[validator] = true;
        emit ValidatorAdded(validator);
    }

    /**
     * @notice Remove a validator
     */
    function removeValidator(address validator) external onlyOwner {
        validators[validator] = false;
        emit ValidatorRemoved(validator);
    }

    /**
     * @notice Set the vault address
     */
    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "Invalid vault");
        vault = BridgeVault(_vault);
    }

    /**
     * @notice Emergency pause
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /**
     * @notice Check if a message was already processed
     */
    function isProcessed(
        uint256 sourceChainId,
        uint256 nonce
    ) external view returns (bool) {
        bytes32 messageId = keccak256(abi.encodePacked(sourceChainId, nonce));
        return processedMessages[messageId];
    }
}
