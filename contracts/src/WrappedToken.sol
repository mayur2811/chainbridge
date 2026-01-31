// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================
// IMPORTS
// ============================================

// ERC20 base contract - gives us all standard token functions
// (transfer, balanceOf, totalSupply, approve, etc.)
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Burn functionality - allows destroying tokens
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

// Admin control
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WrappedToken
 * @notice Represents a bridged token on the destination chain
 * @dev This token is minted when users bridge, burned when they bridge back
 *
 * EXAMPLE:
 * - Original: USDC on Ethereum
 * - Wrapped: wUSDC on Arbitrum (this contract!)
 *
 * INVARIANT:
 * Total wrapped tokens = Total locked in source vault
 * (1 wUSDC on Arbitrum = 1 USDC locked in Ethereum vault)
 *
 * FLOW:
 * Bridge TO Arbitrum: Bridge calls mint() → User gets wUSDC
 * Bridge BACK to Ethereum: User calls burn() → Vault releases USDC
 */
contract WrappedToken is ERC20, ERC20Burnable, Ownable {
    // ============================================
    // STATE VARIABLES
    // ============================================

    /**
     * @notice The bridge contract that can mint tokens
     * @dev ONLY this address can call mint()
     * This is set by admin during deployment
     *
     * WHY IMPORTANT:
     * If anyone could mint → print unlimited fake money = disaster!
     * Only bridge mints after verifying tokens are locked on source
     */
    address public bridge;

    /**
     * @notice Address of the original token on source chain
     * @dev Helps users/UI know "this wUSDC represents USDC at 0x123..."
     *
     * Example: For wUSDC on Arbitrum, this would be:
     * 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 (USDC on Ethereum)
     */
    address public originalToken;

    /**
     * @notice Chain ID where original token lives
     * @dev Helps relayer know where to release tokens when burning
     *
     * Example: For wUSDC bridged from Ethereum, this = 1 (Ethereum mainnet)
     */
    uint256 public originalChainId;

    /**
     * @notice Token decimals (matches original token)
     * @dev USDC has 6 decimals, WETH has 18, etc.
     * Must match original or amounts will be wrong!
     */
    uint8 private _decimals;

    // ============================================
    // EVENTS
    // ============================================

    /**
     * @notice Emitted when tokens are burned for bridging back
     * @dev Relayers watch this to trigger release on source chain
     */
    event TokensBurned(
        address indexed burner, // Who burned
        uint256 amount, // How much
        uint256 indexed destChainId, // Where to release (source chain)
        address indexed recipient, // Who gets tokens on source
        uint256 nonce // Unique ID for this burn
    );

    /**
     * @notice Emitted when bridge address changes
     */
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);

    // ============================================
    // NONCE FOR BURN TRACKING
    // ============================================

    /**
     * @notice Counter for unique burn IDs
     * @dev Same concept as in BridgeVault - prevents replay attacks
     */
    uint256 public burnNonce;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /**
     * @notice Deploy a new wrapped token
     * @param name_ Token name (e.g., "Wrapped USDC")
     * @param symbol_ Token symbol (e.g., "wUSDC")
     * @param decimals_ Must match original token decimals
     * @param originalToken_ Address of token on source chain
     * @param originalChainId_ Chain ID of source chain
     * @param initialOwner Admin who can set bridge
     *
     * DEPLOYMENT EXAMPLE:
     * new WrappedToken(
     *     "Wrapped USDC",           // name
     *     "wUSDC",                  // symbol
     *     6,                        // decimals (USDC = 6)
     *     0xA0b86...eB48,          // USDC address on Ethereum
     *     1,                        // Ethereum chain ID
     *     deployer                  // admin
     * )
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address originalToken_,
        uint256 originalChainId_,
        address initialOwner
    ) ERC20(name_, symbol_) Ownable(initialOwner) {
        require(originalToken_ != address(0), "Invalid original token");
        require(
            originalChainId_ != block.chainid,
            "Cannot wrap token from same chain"
        );

        _decimals = decimals_;
        originalToken = originalToken_;
        originalChainId = originalChainId_;
    }

    // ============================================
    // MODIFIERS
    // ============================================

    /**
     * @notice Only bridge can call functions with this modifier
     * @dev Used on mint() to prevent unauthorized minting
     */
    modifier onlyBridge() {
        require(msg.sender == bridge, "Only bridge can call");
        _;
    }

    // ============================================
    // BRIDGE FUNCTIONS
    // ============================================

    /**
     * @notice Mint wrapped tokens to a user
     * @param to Who receives the tokens
     * @param amount How many tokens to mint
     *
     * ONLY BRIDGE CAN CALL THIS!
     *
     * Called when:
     * 1. User locked tokens on source chain
     * 2. Relayer verified the lock
     * 3. Bridge calls this to give user wrapped tokens
     *
     * EXAMPLE:
     * User locks 100 USDC on Ethereum
     * → Bridge calls mint(user, 100)
     * → User now has 100 wUSDC on Arbitrum
     */
    function mint(address to, uint256 amount) external onlyBridge {
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be > 0");

        // _mint is internal ERC20 function
        // Creates new tokens out of thin air!
        // totalSupply increases by amount
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens to bridge back to source chain
     * @param amount How many tokens to burn
     * @param recipient Who should receive on source chain
     *
     * ANY USER CAN CALL (but only burns THEIR tokens!)
     *
     * Called when:
     * 1. User wants their original tokens back
     * 2. User calls this function
     * 3. Their wrapped tokens are destroyed
     * 4. Relayer sees event → releases originals on source
     *
     * EXAMPLE:
     * User has 100 wUSDC on Arbitrum
     * User calls burnForBridge(100, theirAddress)
     * → 100 wUSDC burned (destroyed)
     * → Event emitted
     * → Relayer releases 100 USDC on Ethereum
     */
    function burnForBridge(uint256 amount, address recipient) external {
        require(amount > 0, "Amount must be > 0");
        require(recipient != address(0), "Invalid recipient");

        // Check user has enough tokens
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        // Increment nonce for unique ID
        burnNonce++;
        uint256 currentNonce = burnNonce;

        // Burn the tokens (destroy them!)
        // _burn is internal ERC20 function
        // totalSupply decreases by amount
        // User balance decreases by amount
        _burn(msg.sender, amount);

        // Emit event - relayer watches this!
        emit TokensBurned(
            msg.sender,
            amount,
            originalChainId, // Where to release (source chain)
            recipient, // Who gets tokens there
            currentNonce
        );
    }

    // ============================================
    // ADMIN FUNCTIONS
    // ============================================

    /**
     * @notice Set the bridge address that can mint
     * @param newBridge The new bridge contract address
     *
     * ONLY OWNER CAN CALL (typically deployer)
     *
     * Called once during setup:
     * 1. Deploy WrappedToken
     * 2. Deploy Bridge
     * 3. Call setBridge(bridgeAddress)
     * 4. Now only that bridge can mint
     */
    function setBridge(address newBridge) external onlyOwner {
        require(newBridge != address(0), "Invalid bridge address");

        address oldBridge = bridge;
        bridge = newBridge;

        emit BridgeUpdated(oldBridge, newBridge);
    }

    // ============================================
    // VIEW FUNCTIONS (Override)
    // ============================================

    /**
     * @notice Returns token decimals
     * @dev Overrides ERC20 default (18) to match original token
     *
     * IMPORTANT: Must match original token!
     * USDC = 6 decimals, WETH = 18 decimals
     *
     * If we got this wrong:
     * Lock 100 USDC (6 decimals) = 100,000,000 wei
     * Mint 100 wUSDC (18 decimals) = 100,000,000,000,000,000 wei
     * → User gets 1 BILLION times more! 💀
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    // ============================================
    // HELPER VIEW FUNCTIONS
    // ============================================

    /**
     * @notice Get all token metadata in one call
     * @return name_ Token name
     * @return symbol_ Token symbol
     * @return decimals_ Token decimals
     * @return originalToken_ Address of original token on source chain
     * @return originalChainId_ Chain ID of source chain
     *
     * Useful for UI to display:
     * "wUSDC (Wrapped from USDC on Ethereum)"
     */
    function getTokenInfo()
        external
        view
        returns (
            string memory name_,
            string memory symbol_,
            uint8 decimals_,
            address originalToken_,
            uint256 originalChainId_
        )
    {
        return (name(), symbol(), _decimals, originalToken, originalChainId);
    }
}
