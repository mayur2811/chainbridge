# Security Documentation

## Overview

ChainBridge implements multiple layers of security to protect user funds and prevent attack vectors common in cross-chain bridges.

## Security Model

```
┌─────────────────────────────────────────────────────┐
│                  SECURITY LAYERS                     │
│                                                      │
│  Layer 1: Smart Contract Security                    │
│  ├── ReentrancyGuard                                │
│  ├── SafeERC20                                      │
│  ├── Access Control (Ownable, Validators)           │
│  └── Pausable                                       │
│                                                      │
│  Layer 2: Protocol Security                          │
│  ├── Nonce-based replay prevention                  │
│  ├── Multi-sig validator system                     │
│  ├── Message hash verification                      │
│  └── Emergency withdrawal mechanism                 │
│                                                      │
│  Layer 3: Operational Security                       │
│  ├── Private key management                         │
│  ├── Block confirmation waiting                     │
│  └── Contract pausability                           │
│                                                      │
└─────────────────────────────────────────────────────┘
```

## Attack Vectors and Mitigations

### 1. Reentrancy Attack

**Risk**: Attacker re-enters lockTokens() or releaseTokens() during execution.

**Mitigation**: `ReentrancyGuard` from OpenZeppelin on all state-changing functions.

```solidity
function lockTokens(...) external nonReentrant whenNotPaused { ... }
function releaseTokens(...) external nonReentrant whenNotPaused { ... }
```

### 2. Replay Attack

**Risk**: Attacker replays a valid bridge transaction to double-mint or double-release.

**Mitigation**: Nonce-based deduplication system.

```solidity
// Each bridge operation has a unique nonce
mapping(uint256 => bool) public processedNonces;

// In releaseTokens():
require(!processedNonces[sourceNonce], "Already processed");
processedNonces[sourceNonce] = true;
```

Router uses `keccak256(sourceChainId, nonce)` for cross-chain message deduplication.

### 3. Unauthorized Minting

**Risk**: Attacker calls mint() on WrappedToken to create tokens without locking.

**Mitigation**: Only the authorized bridge contract can mint.

```solidity
modifier onlyBridge() {
    require(msg.sender == bridge, "Only bridge can call");
    _;
}

function mint(address to, uint256 amount) external onlyBridge { ... }
```

### 4. Unauthorized Token Release

**Risk**: Attacker calls releaseTokens() to steal locked funds.

**Mitigation**: Only registered validators can release tokens.

```solidity
require(validators[msg.sender], "Not a validator");
```

### 5. Token Approval Exploit

**Risk**: Malicious token with non-standard approve/transfer behavior.

**Mitigation**: OpenZeppelin `SafeERC20` library handles non-standard tokens.

```solidity
using SafeERC20 for IERC20;
IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
```

### 6. Dust Attack

**Risk**: Attacker spams tiny bridge transactions to DOS the relayer.

**Mitigation**: Minimum bridge amount per token.

```solidity
mapping(address => uint256) public minBridgeAmount;

require(amount >= minBridgeAmount[token], "Below minimum");
```

### 7. Relayer Failure

**Risk**: Relayer goes offline, users have tokens locked with no way to recover.

**Mitigation**: Emergency withdrawal mechanism with time delay.

```solidity
function emergencyWithdraw(uint256 lockNonce) external nonReentrant {
    LockInfo storage lock = lockInfo[lockNonce];

    require(lock.sender == msg.sender, "Not your lock");
    require(!lock.completed, "Already completed");
    require(
        block.timestamp >= lock.timestamp + emergencyWithdrawDelay,
        "Too early"
    );

    // Return tokens to user
    IERC20(lock.token).safeTransfer(msg.sender, lock.amount);
}
```

**Time delay** (default 7 days) ensures:

- Relayer has time to process normally
- Prevents abusing emergency withdraw to double-spend
- `markBridgeCompleted()` prevents withdrawal after successful bridge

### 8. Cross-Chain Message Forgery

**Risk**: Attacker creates fake bridge messages.

**Mitigation**: Message hash includes all parameters + chain IDs.

```solidity
keccak256(abi.encodePacked(
    "BRIDGE_LOCK",     // Type prefix
    token,             // Exact token address
    recipient,         // Exact recipient
    amount,            // Exact amount
    sourceChainId,     // Source chain
    destChainId,       // Destination chain
    nonce              // Unique ID
))
```

### 9. Validator Compromise

**Risk**: A validator's private key is compromised.

**Mitigation**:

- Multi-sig: Can require multiple validator signatures (threshold > 1)
- Validator removal: Owner can remove compromised validators
- Contract pause: Owner can pause all operations immediately

### 10. Emergency Scenarios

**Risk**: Critical bug discovered, funds at risk.

**Mitigation**: Pausable pattern.

```solidity
function pause() external onlyOwner { _pause(); }
function unpause() external onlyOwner { _unpause(); }
```

All critical functions use `whenNotPaused` modifier.

## OpenZeppelin Dependencies

| Library          | Version | Usage                   |
| ---------------- | ------- | ----------------------- |
| ReentrancyGuard  | ^5.0    | Prevent reentrancy      |
| SafeERC20        | ^5.0    | Safe token transfers    |
| Ownable          | ^5.0    | Admin access control    |
| Pausable         | ^5.0    | Emergency stop          |
| ECDSA            | ^5.0    | Signature verification  |
| MessageHashUtils | ^5.0    | EIP-191 hash formatting |
| ERC20            | ^5.0    | Token standard          |
| ERC20Burnable    | ^5.0    | Burn capability         |

## Known Limitations

1. **Single Validator Setup**: Currently using 1 validator (threshold=1). In production, should use 3+ validators
2. **No Fee System**: Bridge is free. Production would need fee mechanism for sustainability
3. **No Rate Limiting**: No per-block or per-user rate limits
4. **Testnet Only**: Deployed on testnets, not audited for mainnet

## Audit Status

This is a portfolio/demonstration project. The contracts have NOT been professionally audited. The frontend displays "Testnet Demo - Not Audited" to communicate this clearly.

## Recommendations for Production

1. Professional smart contract audit
2. Minimum 3 validators with threshold of 2
3. Rate limiting per address
4. Fee mechanism
5. Time-locked admin operations
6. Monitoring and alerting system
7. Insurance fund for potential exploits
