/**
 * ============================================
 * CHAINBRIDGE RELAYER - CONTRACT ABIs
 * ============================================
 * 
 * These are the ABI (Application Binary Interface) definitions
 * for interacting with our smart contracts.
 * 
 * WHY ABIs?
 * - ABIs tell ethers.js how to encode/decode function calls
 * - We only include the functions/events we need (minimal ABI)
 * - This keeps the relayer lightweight
 */

/**
 * BridgeVault ABI - for listening to lock events
 * 
 * Events we care about:
 * - TokensLocked: Emitted when user locks tokens on source chain
 */
export const BRIDGE_VAULT_ABI = [
  // Event: TokensLocked
  "event TokensLocked(address indexed sender, address indexed token, uint256 amount, uint256 indexed destChainId, address recipient, uint256 nonce)",
  
  // View: Get nonce
  "function nonce() view returns (uint256)",
  
  // View: Get lock info
  "function lockInfo(uint256 nonce) view returns (address sender, address token, uint256 amount, uint256 timestamp, bool completed, bool withdrawn)"
];

/**
 * BridgeRouter ABI - for executing bridge completions
 * 
 * Functions we call:
 * - completeBridge: Mint wrapped tokens on destination
 * - releaseBridge: Release original tokens when bridging back
 */
export const BRIDGE_ROUTER_ABI = [
  // Event: BridgeInitiated (source chain)
  "event BridgeInitiated(address indexed sender, address indexed token, uint256 amount, uint256 indexed destChainId, address recipient, uint256 nonce)",
  
  // Event: BridgeCompleted (destination chain)
  "event BridgeCompleted(address indexed recipient, address indexed wrappedToken, uint256 amount, uint256 sourceChainId, uint256 nonce)",
  
  // Event: BridgeReleased (source chain)
  "event BridgeReleased(address indexed recipient, address indexed token, uint256 amount, uint256 sourceChainId, uint256 nonce)",
  
  // Function: Complete bridge by minting wrapped tokens
  "function completeBridge(address originalToken, address recipient, uint256 amount, uint256 sourceChainId, uint256 nonce) external",
  
  // Function: Release original tokens
  "function releaseBridge(address token, address recipient, uint256 amount, uint256 sourceChainId, uint256 nonce) external",
  
  // View: Check if message was processed
  "function isProcessed(uint256 sourceChainId, uint256 nonce) view returns (bool)"
];

/**
 * WrappedToken ABI - for listening to burn events
 * 
 * Events we care about:
 * - TokensBurned: Emitted when user burns wrapped tokens to bridge back
 */
export const WRAPPED_TOKEN_ABI = [
  // Event: TokensBurned
  "event TokensBurned(address indexed burner, uint256 amount, uint256 indexed destChainId, address recipient, uint256 nonce)",
  
  // View: Get burn nonce
  "function burnNonce() view returns (uint256)",
  
  // View: Get original token info
  "function originalToken() view returns (address)",
  "function originalChainId() view returns (uint256)"
];
