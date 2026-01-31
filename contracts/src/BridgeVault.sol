// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================
// IMPORTS - Security tools from OpenZeppelin
// ============================================

// Interface to interact with any ERC20 token (USDC, WETH, DAI, etc.)
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Safe way to transfer tokens - handles broken tokens like USDT
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Prevents reentrancy attacks (like The DAO hack)
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Emergency stop button - can pause contract if exploit detected
import "@openzeppelin/contracts/utils/Pausable.sol";

// Admin control - only owner can do certain things
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BridgeVault
 * @notice Locks tokens on source chain for cross-chain bridging
 * @dev This is where users deposit tokens when they want to bridge
 *
 * FLOW:
 * 1. User approves this contract to spend their tokens
 * 2. User calls lockTokens() with amount and destination chain
 * 3. Contract pulls tokens from user and holds them
 * 4. Contract emits TokensLocked event
 * 5. Relayer sees event and triggers mint on destination chain
 */
contract BridgeVault is ReentrancyGuard, Pausable, Ownable {
    // This line lets us use safeTransfer() on any IERC20 token
    using SafeERC20 for IERC20;

    // ============================================
    // STATE VARIABLES
    // ============================================

    /**
     * @notice Counter for unique deposit IDs
     * @dev Increases by 1 for each deposit - prevents replay attacks
     * Example: Deposit 1 = nonce 1, Deposit 2 = nonce 2, etc.
     */
    uint256 public nonce;

    /**
     * @notice Whitelist of tokens that can be bridged
     * @dev Only approved tokens can be locked (prevents spam tokens)
     * Example: supportedTokens[USDC_address] = true
     */
    mapping(address => bool) public supportedTokens;

    /**
     * @notice Addresses that can release tokens (trusted validators)
     * @dev Only validators can call releaseTokens()
     * These are addresses that verify burns happened on destination chain
     */
    mapping(address => bool) public validators;

    /**
     * @notice Track which nonces were already processed
     * @dev Prevents the same message from being used twice (replay attack)
     * Example: processedNonces[5] = true means nonce 5 was already used
     */
    mapping(uint256 => bool) public processedNonces;

    /**
     * @notice Minimum amount that can be bridged per token
     * @dev Prevents dust attacks (bridging tiny amounts to spam)
     */
    mapping(address => uint256) public minBridgeAmount;

    /**
     * @notice Time delay before emergency withdrawal is allowed
     * @dev Default 7 days - gives relayer time to process
     */
    uint256 public emergencyWithdrawDelay = 7 days;

    /**
     * @notice Stores information about each lock for emergency withdrawal
     * @dev Allows users to recover funds if relayer fails
     */
    struct LockInfo {
        address sender;      // Who locked the tokens
        address token;       // Which token
        uint256 amount;      // How much
        uint256 timestamp;   // When it was locked
        bool completed;      // Whether bridge was completed
        bool withdrawn;      // Whether emergency withdrawn
    }

    /**
     * @notice Maps nonce → lock information
     * @dev Used for emergency withdrawal if relayer fails
     */
    mapping(uint256 => LockInfo) public lockInfo;

    // ============================================
    // EVENTS - These are what relayers listen for!
    // ============================================

    /**
     * @notice Emitted when tokens are locked for bridging
     * @dev Relayers monitor this event to trigger minting on destination
     *
     * indexed = makes it easy to search/filter events
     * Example: Find all events where destChainId = 42161 (Arbitrum)
     */
    event TokensLocked(
        address indexed sender, // Who deposited the tokens
        address indexed token, // Which token (USDC, WETH, etc.)
        uint256 amount, // How many tokens
        uint256 indexed destChainId, // Where they're going (chain ID)
        address recipient, // Who receives on destination
        uint256 nonce // Unique ID for this deposit
    );

    /**
     * @notice Emitted when tokens are released (bridging back)
     * @dev Happens when someone burns wrapped tokens on destination
     */
    event TokensReleased(
        address indexed recipient, // Who receives the tokens
        address indexed token, // Which token
        uint256 amount, // How many
        uint256 sourceChainId, // Which chain they came from
        uint256 nonce // Original deposit ID
    );

    // Admin events
    event TokenAdded(address indexed token, uint256 minAmount);
    event TokenRemoved(address indexed token);
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);

    /**
     * @notice Emitted when user does emergency withdrawal
     * @dev Happens when relayer fails and user reclaims funds after delay
     */
    event EmergencyWithdrawal(
        address indexed sender,
        address indexed token,
        uint256 amount,
        uint256 nonce
    );

    /**
     * @notice Emitted when bridge is marked complete (prevents emergency withdraw)
     */
    event BridgeCompleted(uint256 indexed nonce);

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /**
     * @notice Sets up the vault with an owner
     * @param initialOwner The admin who can add tokens/validators
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        // Owner is set by Ownable constructor
        // Contract starts unpaused
    }

    // ============================================
    // USER FUNCTIONS - Anyone can call these
    // ============================================

    /**
     * @notice Lock tokens to bridge them to another chain
     * @param token The token address to bridge (must be supported)
     * @param amount How many tokens to bridge
     * @param destChainId The destination chain ID (e.g., 42161 for Arbitrum)
     * @param recipient Who should receive tokens on destination chain
     *
     * BEFORE CALLING: User must approve this contract to spend their tokens!
     * Example: USDC.approve(bridgeVault, 1000) then lockTokens(USDC, 1000, ...)
     *
     * nonReentrant = Prevents reentrancy attack
     * whenNotPaused = Can't use if contract is paused (emergency)
     */
    function lockTokens(
        address token,
        uint256 amount,
        uint256 destChainId,
        address recipient
    ) external nonReentrant whenNotPaused {
        // CHECKS - Verify everything is valid before doing anything

        // 1. Is this token allowed?
        require(supportedTokens[token], "Token not supported");

        // 2. Is amount valid?
        require(amount >= minBridgeAmount[token], "Amount below minimum");

        // 3. Is recipient valid?
        require(recipient != address(0), "Invalid recipient");

        // 4. Is destination chain valid? (can't bridge to same chain)
        require(destChainId != block.chainid, "Cannot bridge to same chain");

        // EFFECTS - Update state BEFORE external calls (CEI pattern)

        // 5. Increment nonce for unique ID
        nonce++;
        uint256 currentNonce = nonce;

        // 6. Store lock info for emergency withdrawal
        lockInfo[currentNonce] = LockInfo({
            sender: msg.sender,
            token: token,
            amount: amount,
            timestamp: block.timestamp,
            completed: false,
            withdrawn: false
        });

        // INTERACTIONS - External calls last (safest)

        // 7. Pull tokens from user to this vault
        // safeTransferFrom handles weird tokens like USDT
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // 8. Emit event - Relayers will see this and trigger mint!
        emit TokensLocked(
            msg.sender,
            token,
            amount,
            destChainId,
            recipient,
            currentNonce
        );
    }

    // ============================================
    // VALIDATOR FUNCTIONS - Only trusted validators
    // ============================================

    /**
     * @notice Release tokens when someone bridges back
     * @param token Which token to release
     * @param recipient Who gets the tokens
     * @param amount How many tokens
     * @param sourceChainId Which chain the burn happened on
     * @param sourceNonce The original nonce from destination chain
     *
     * This is called by validators after they verify:
     * 1. Wrapped tokens were burned on destination chain
     * 2. The burn event is legitimate
     */
    function releaseTokens(
        address token,
        address recipient,
        uint256 amount,
        uint256 sourceChainId,
        uint256 sourceNonce
    ) external nonReentrant whenNotPaused {
        // CHECKS

        // 1. Only validators can release tokens
        require(validators[msg.sender], "Not a validator");

        // 2. This nonce must not have been used before (prevent replay)
        require(!processedNonces[sourceNonce], "Already processed");

        // 3. Basic validation
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");

        // EFFECTS - Mark as processed BEFORE sending (prevents exploit!)
        processedNonces[sourceNonce] = true;

        // INTERACTIONS - Send tokens
        IERC20(token).safeTransfer(recipient, amount);

        // Emit event for tracking
        emit TokensReleased(
            recipient,
            token,
            amount,
            sourceChainId,
            sourceNonce
        );
    }

    /**
     * @notice Mark a bridge as completed (prevents emergency withdrawal)
     * @param lockNonce The nonce of the lock on this chain
     * 
     * Called by validator after successfully minting on destination
     * This prevents user from both getting minted tokens AND emergency withdrawing
     */
    function markBridgeCompleted(uint256 lockNonce) external {
        require(validators[msg.sender], "Not a validator");
        require(lockInfo[lockNonce].sender != address(0), "Lock does not exist");
        require(!lockInfo[lockNonce].completed, "Already completed");
        require(!lockInfo[lockNonce].withdrawn, "Already withdrawn");
        
        lockInfo[lockNonce].completed = true;
        emit BridgeCompleted(lockNonce);
    }

    // ============================================
    // EMERGENCY FUNCTIONS - For stuck funds
    // ============================================

    /**
     * @notice Emergency withdrawal if relayer fails to complete bridge
     * @param lockNonce The nonce of your lock
     * 
     * CAN ONLY BE CALLED:
     * 1. By the original sender (who locked the tokens)
     * 2. After emergencyWithdrawDelay (default 7 days)
     * 3. If bridge was NOT completed (no double-spending!)
     * 4. If NOT already withdrawn
     * 
     * FLOW:
     * Day 1: User locks tokens, relayer is supposed to mint
     * Day 2-7: User waits...
     * Day 7+: Relayer still dead? User calls emergencyWithdraw()
     * Result: User gets their locked tokens back ✅
     */
    function emergencyWithdraw(uint256 lockNonce) external nonReentrant {
        LockInfo storage lock = lockInfo[lockNonce];
        
        // CHECKS
        
        // 1. Does this lock exist?
        require(lock.sender != address(0), "Lock does not exist");
        
        // 2. Is caller the original sender?
        require(lock.sender == msg.sender, "Not your lock");
        
        // 3. Has enough time passed?
        require(
            block.timestamp >= lock.timestamp + emergencyWithdrawDelay,
            "Too early - wait for delay period"
        );
        
        // 4. Was bridge NOT completed? (prevent double-spending)
        require(!lock.completed, "Bridge was completed - cannot withdraw");
        
        // 5. Not already withdrawn?
        require(!lock.withdrawn, "Already withdrawn");
        
        // EFFECTS - Mark as withdrawn BEFORE sending
        lock.withdrawn = true;
        
        // INTERACTIONS - Send tokens back
        IERC20(lock.token).safeTransfer(msg.sender, lock.amount);
        
        emit EmergencyWithdrawal(msg.sender, lock.token, lock.amount, lockNonce);
    }

    /**
     * @notice Set emergency withdrawal delay (admin only)
     * @param newDelay New delay in seconds
     */
    function setEmergencyWithdrawDelay(uint256 newDelay) external onlyOwner {
        require(newDelay >= 1 days, "Delay too short");
        require(newDelay <= 30 days, "Delay too long");
        emergencyWithdrawDelay = newDelay;
    }

    // ============================================
    // ADMIN FUNCTIONS - Only owner can call
    // ============================================

    /**
     * @notice Add a token that can be bridged
     * @param token The token address
     * @param minAmount Minimum amount that can be bridged
     */
    function addSupportedToken(
        address token,
        uint256 minAmount
    ) external onlyOwner {
        require(token != address(0), "Invalid token");
        supportedTokens[token] = true;
        minBridgeAmount[token] = minAmount;
        emit TokenAdded(token, minAmount);
    }

    /**
     * @notice Remove a token from supported list
     * @param token The token to remove
     */
    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
        emit TokenRemoved(token);
    }

    /**
     * @notice Add a trusted validator
     * @param validator The address to add
     */
    function addValidator(address validator) external onlyOwner {
        require(validator != address(0), "Invalid validator");
        validators[validator] = true;
        emit ValidatorAdded(validator);
    }

    /**
     * @notice Remove a validator
     * @param validator The address to remove
     */
    function removeValidator(address validator) external onlyOwner {
        validators[validator] = false;
        emit ValidatorRemoved(validator);
    }

    /**
     * @notice Emergency pause - stops all deposits and releases
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============================================
    // VIEW FUNCTIONS - Read-only, no gas cost
    // ============================================

    /**
     * @notice Check how many tokens are locked in this vault
     * @param token The token to check
     * @return The balance of that token in this contract
     */
    function getLockedBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
