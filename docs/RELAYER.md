# Relayer Service Documentation

## Overview

The relayer is a Node.js TypeScript off-chain service that monitors blockchain events and executes cross-chain bridge operations. It acts as the communication layer between the source and destination chains.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                  RELAYER SERVICE                      │
│                                                      │
│  index.ts (Entry Point)                              │
│     │                                                │
│     ├── config.ts (Configuration & Chain Setup)      │
│     │                                                │
│     ├── bridge-listener.ts (Event Monitoring)        │
│     │     ├── Sepolia: TokensLocked events           │
│     │     └── Hoodi: TokensBurned events             │
│     │                                                │
│     ├── bridge-executor.ts (Transaction Execution)   │
│     │     ├── completeBridge() on Hoodi              │
│     │     └── releaseBridge() on Sepolia             │
│     │                                                │
│     └── abis.ts (Contract ABIs)                      │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## File Breakdown

### index.ts (Entry Point)

Main file that initializes the relayer and starts listening for events on both chains.

**Responsibilities:**

- Load environment configuration
- Initialize wallet signers for both chains
- Start bidirectional event listeners
- Handle graceful shutdown

### config.ts (Configuration)

Manages chain configuration, RPC endpoints, and contract addresses.

**Key Config:**

```typescript
{
  sepolia: {
    chainId: 11155111,
    rpc: "https://ethereum-sepolia-rpc.publicnode.com",
    vault: "0xcD54...",
    router: "0xcF1C...",
    testToken: "0x9f76..."
  },
  hoodi: {
    chainId: 560048,
    rpc: "https://rpc.hoodi.ethpandaops.io",
    router: "0xcF1C...",
    wrappedToken: "0xabB8..."
  }
}
```

### bridge-listener.ts (Event Monitoring)

Listens for bridge events on both chains using ethers.js providers.

**Events Monitored:**

| Event          | Chain   | Trigger                    |
| -------------- | ------- | -------------------------- |
| `TokensLocked` | Sepolia | User locks tokens in vault |
| `TokensBurned` | Hoodi   | User burns wrapped tokens  |

**Event Handler Flow:**

```
TokensLocked Event (Sepolia)
     │
     ├── Parse: sender, token, amount, destChainId, recipient, nonce
     ├── Wait for block confirmations
     └── Call bridge-executor.completeBridge()

TokensBurned Event (Hoodi)
     │
     ├── Parse: burner, amount, destChainId, recipient, burnNonce
     ├── Wait for block confirmations
     └── Call bridge-executor.releaseBridge()
```

### bridge-executor.ts (Transaction Execution)

Executes bridge completion transactions on the destination chain.

**Functions:**

| Function           | Target Chain | Action                                                |
| ------------------ | ------------ | ----------------------------------------------------- |
| `completeBridge()` | Hoodi        | Calls Router.completeBridge() to mint wrapped tokens  |
| `releaseBridge()`  | Sepolia      | Calls Router.releaseBridge() to release locked tokens |

### abis.ts (Contract ABIs)

Contains the ABI definitions for all contract interactions.

## Event Processing Flow

### Forward Bridge (Sepolia → Hoodi)

```
1. User calls vault.lockTokens() on Sepolia
         │
2. Event: TokensLocked(sender, token, amount, destChainId, recipient, nonce)
         │
3. Relayer captures event
         │
4. Relayer waits for N block confirmations
         │
5. Relayer calls router.completeBridge() on Hoodi
   Parameters: originalToken, recipient, amount, sepoliaChainId, nonce
         │
6. Router calls wrappedToken.mint(recipient, amount)
         │
7. User receives wTEST tokens on Hoodi
```

### Reverse Bridge (Hoodi → Sepolia)

```
1. User calls wrappedToken.burnForBridge(amount, recipient) on Hoodi
         │
2. Event: TokensBurned(burner, amount, destChainId, recipient, burnNonce)
         │
3. Relayer captures event
         │
4. Relayer waits for N block confirmations
         │
5. Relayer calls router.releaseBridge() on Sepolia
   Parameters: token, recipient, amount, hoodiChainId, nonce
         │
6. Router calls vault.releaseTokens()
         │
7. User receives TEST tokens on Sepolia
```

## Configuration

### Environment Variables

```env
# Private key for relayer wallet (must be a registered validator)
PRIVATE_KEY=0x...

# RPC URLs
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
HOODI_RPC_URL=https://rpc.hoodi.ethpandaops.io

# Contract addresses are hardcoded in config.ts
```

### Running the Relayer

```bash
cd relayer
npm install
npm run dev
```

### Output

```
╔════════════════════════════════════════════════╗
║  CHAINBRIDGE RELAYER v2.0 - BIDIRECTIONAL     ║
╚════════════════════════════════════════════════╝

Relayer: 0x2b4446...

Listening on:
   Sepolia Vault: 0xcD54...
   Hoodi wTEST: 0xabB8...

[Sepolia→Hoodi] Listening for TokensLocked...
[Hoodi→Sepolia] Listening for TokensBurned...

Relayer ready! Watching both chains...
```

## Error Handling

The relayer handles:

- RPC connection failures (automatic reconnection)
- Transaction failures (logged with details)
- Gas estimation errors (uses gas limit fallback)
- Duplicate event processing (nonce-based deduplication)

## Security Considerations

- **Private Key**: Stored in `.env` file, never committed to git
- **Validator Role**: Relayer wallet must be registered as validator on contracts
- **Confirmation Wait**: Waits for block confirmations before executing
- **Nonce Check**: Contract-level nonce prevents reprocessing
