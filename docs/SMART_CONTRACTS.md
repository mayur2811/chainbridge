# Smart Contracts Documentation

## Overview

ChainBridge consists of 5 smart contracts written in Solidity ^0.8.20, using OpenZeppelin libraries for security.

| Contract            | LOC | Purpose                              |
| ------------------- | --- | ------------------------------------ |
| BridgeVault.sol     | 443 | Token custody on source chain        |
| BridgeRouter.sol    | 406 | Main entry point and orchestrator    |
| WrappedToken.sol    | 313 | ERC-20 wrapped tokens on destination |
| ValidatorSet.sol    | 305 | Multi-sig validator management       |
| MessageVerifier.sol | 259 | Bridge message proof verification    |

---

## BridgeVault.sol

**Purpose**: Holds user tokens on the source chain when they bridge to another network.

**Inherits**: `ReentrancyGuard`, `Pausable`, `Ownable`

### Key Functions

| Function                                                        | Access     | Description                                 |
| --------------------------------------------------------------- | ---------- | ------------------------------------------- |
| `lockTokens(token, amount, destChainId, recipient)`             | Public     | Lock ERC-20 tokens for bridging             |
| `releaseTokens(token, recipient, amount, sourceChainId, nonce)` | Validator  | Release tokens on reverse bridge            |
| `emergencyWithdraw(lockNonce)`                                  | Lock Owner | Reclaim tokens if relayer fails             |
| `markBridgeCompleted(lockNonce)`                                | Validator  | Prevent emergency withdraw after completion |

### State Variables

```solidity
mapping(address => bool) public supportedTokens;     // Allowed tokens
mapping(address => bool) public validators;           // Authorized validators
mapping(uint256 => LockInfo) public lockInfo;         // Lock records
mapping(uint256 => bool) public processedNonces;      // Replay prevention
mapping(address => uint256) public minBridgeAmount;   // Dust attack prevention
uint256 public emergencyWithdrawDelay;                // Default: 7 days
```

### Events

```solidity
event TokensLocked(sender, token, amount, destChainId, recipient, nonce);
event TokensReleased(recipient, token, amount, sourceChainId, nonce);
event EmergencyWithdrawal(sender, token, amount, nonce);
event BridgeCompleted(nonce);
```

### Security Features

- **ReentrancyGuard**: Prevents reentrancy attacks on lock/release
- **SafeERC20**: Handles non-standard tokens (USDT-style)
- **Nonce tracking**: Prevents double-spending
- **Emergency withdrawal**: 7-day delay safety net
- **Pausable**: Admin can halt operations in emergencies

---

## BridgeRouter.sol

**Purpose**: Main entry point for users. Coordinates between Vault, WrappedToken, and validators.

**Inherits**: `ReentrancyGuard`, `Pausable`, `Ownable`

### Key Functions

| Function                                                                 | Access    | Description                               |
| ------------------------------------------------------------------------ | --------- | ----------------------------------------- |
| `bridge(token, amount, destChainId, recipient)`                          | Public    | Initiate a bridge (calls Vault)           |
| `completeBridge(originalToken, recipient, amount, sourceChainId, nonce)` | Validator | Mint wrapped tokens on destination        |
| `releaseBridge(token, recipient, amount, sourceChainId, nonce)`          | Validator | Release tokens on source (reverse bridge) |
| `registerWrappedToken(originalToken, wrappedToken)`                      | Owner     | Map original → wrapped token              |

### Token Registration

```
Router.registerWrappedToken(
    0x9f76...  // TEST token on Sepolia
    0xabB8...  // wTEST token on Hoodi
)
```

This mapping tells the Router which wrapped token to mint when tokens arrive from a specific original token.

### Message Deduplication

Uses `keccak256(sourceChainId, nonce)` as a unique message ID to prevent replay attacks.

---

## WrappedToken.sol

**Purpose**: ERC-20 token that represents locked tokens from another chain. Minted by Bridge, burned by users.

**Inherits**: `ERC20`, `ERC20Burnable`, `Ownable`

### Key Functions

| Function                           | Access      | Description                                   |
| ---------------------------------- | ----------- | --------------------------------------------- |
| `mint(to, amount)`                 | Bridge Only | Create wrapped tokens                         |
| `burnForBridge(amount, recipient)` | Public      | Burn tokens to bridge back                    |
| `setBridge(newBridge)`             | Owner       | Set authorized bridge address                 |
| `getTokenInfo()`                   | View        | Returns name, symbol, decimals, original info |

### Burn Flow

When a user calls `burnForBridge()`:

1. Tokens are destroyed (burned)
2. `TokensBurned` event is emitted with burn details
3. Burn nonce increments
4. Relayer picks up event and releases on source chain

### Events

```solidity
event TokensBurned(burner, amount, destChainId, recipient, burnNonce);
event BridgeUpdated(oldBridge, newBridge);
```

---

## ValidatorSet.sol

**Purpose**: Manages a set of validators who authorize bridge operations via multi-signature.

**Inherits**: `Ownable`

### Key Functions

| Function                                    | Access | Description                      |
| ------------------------------------------- | ------ | -------------------------------- |
| `verifySignatures(messageHash, signatures)` | View   | Verify multi-sig meets threshold |
| `addValidator(validator)`                   | Owner  | Add new validator                |
| `removeValidator(validator)`                | Owner  | Remove validator                 |
| `setThreshold(newThreshold)`                | Owner  | Change required signatures       |
| `createBridgeMessageHash(...)`              | View   | Create hash for signing          |

### Multi-Sig Process

```
Message Data ──► Hash ──► Validators Sign ──► Signatures Submitted
                                                      │
                                    ValidatorSet.verifySignatures()
                                                      │
                                    Checks: threshold met? ──► Yes ──► Approve
                                                             No  ──► Revert
```

### Threshold Logic

- `threshold = 1` means 1 of N validators must sign (current setup)
- `threshold = 3` would mean 3 of N validators must sign
- Threshold auto-adjusts down if validators are removed below threshold

---

## MessageVerifier.sol

**Purpose**: Glue between BridgeRouter and ValidatorSet. Creates message hashes and verifies signatures.

### Key Functions

| Function                                                                       | Access   | Description                       |
| ------------------------------------------------------------------------------ | -------- | --------------------------------- |
| `verifyBridgeLock(token, recipient, amount, sourceChainId, nonce, signatures)` | External | Verify lock message for minting   |
| `verifyBridgeBurn(token, recipient, amount, sourceChainId, nonce, signatures)` | External | Verify burn message for releasing |
| `hashBridgeLock(...)`                                                          | View     | Create lock message hash          |
| `hashBridgeBurn(...)`                                                          | View     | Create burn message hash          |

### Hash Structure

Lock Hash:

```
keccak256("BRIDGE_LOCK", token, recipient, amount, sourceChainId, destChainId, nonce)
```

Burn Hash:

```
keccak256("BRIDGE_BURN", token, recipient, amount, sourceChainId, destChainId, nonce)
```

The type prefix (`BRIDGE_LOCK` vs `BRIDGE_BURN`) prevents cross-type hash collisions.

---

## Contract Interactions

```
User Action: bridge(token, amount, destChain, recipient)
     │
     ▼
BridgeRouter.bridge()
     │
     ├── Check: supported chain? ✓
     ├── Check: amount > 0? ✓
     │
     ▼
BridgeVault.lockTokens()
     │
     ├── Check: supported token? ✓
     ├── Check: amount >= minimum? ✓
     ├── SafeERC20.transferFrom(user → vault)
     ├── lockInfo[nonce] = LockInfo{...}
     ├── Emit TokensLocked event
     │
     ▼
[Off-Chain: Relayer detects event]
     │
     ▼
BridgeRouter.completeBridge() [on destination chain]
     │
     ├── Check: not processed? ✓
     ├── Check: caller is validator? ✓
     │
     ▼
WrappedToken.mint(recipient, amount)
     │
     └── User receives wrapped tokens ✓
```

---

## Deployment Addresses

### Sepolia (Chain ID: 11155111)

| Contract     | Address                                      |
| ------------ | -------------------------------------------- |
| BridgeVault  | `0xcD54697e22264a0c496606301ae19421c690f3dc` |
| BridgeRouter | `0xcF1C4C9ad85185ae346F71beCae1A92a41d857f5` |
| TEST Token   | `0x9f76259FF348362e23753815d351c5F4177b77B7` |

### Hoodi (Chain ID: 560048)

| Contract     | Address                                      |
| ------------ | -------------------------------------------- |
| BridgeRouter | `0xcF1C4C9ad85185ae346F71beCae1A92a41d857f5` |
| wTEST Token  | `0xabB81B91BE2B922E6059844ed844D5660b41A75f` |

---

## Testing

77 unit tests covering all contracts:

```bash
forge test -vv
```

| Test File             | Tests | Coverage                                 |
| --------------------- | ----- | ---------------------------------------- |
| BridgeVault.t.sol     | ~20   | Lock, release, emergency, access control |
| BridgeRouter.t.sol    | ~18   | Bridge, complete, release, registration  |
| WrappedToken.t.sol    | ~15   | Mint, burn, access control, decimals     |
| ValidatorSet.t.sol    | ~12   | Add/remove, threshold, signatures        |
| MessageVerifier.t.sol | ~12   | Hash creation, verification              |
