# ChainBridge Architecture

## System Overview

ChainBridge is a cross-chain token bridge built on the **lock-and-mint / burn-and-release** model. It enables trustless ERC-20 token transfers between Ethereum-compatible networks.

## High-Level Architecture

```
                        CHAINBRIDGE SYSTEM
┌──────────────────────────────────────────────────────┐
│                                                      │
│  ┌──────────────┐    Off-Chain     ┌──────────────┐  │
│  │ SOURCE CHAIN │    Relayer       │  DEST CHAIN  │  │
│  │  (Sepolia)   │◄───────────────►│   (Hoodi)    │  │
│  └──────┬───────┘                  └──────┬───────┘  │
│         │                                 │          │
│  ┌──────┴───────┐                  ┌──────┴───────┐  │
│  │ BridgeVault  │                  │WrappedToken  │  │
│  │ BridgeRouter │                  │BridgeRouter  │  │
│  │ ValidatorSet │                  │ValidatorSet  │  │
│  │ MsgVerifier  │                  │MsgVerifier   │  │
│  │ TEST Token   │                  │ wTEST Token  │  │
│  └──────────────┘                  └──────────────┘  │
│                                                      │
│  ┌──────────────────────────────────────────────┐    │
│  │              FRONTEND (Next.js)              │    │
│  │  Wallet Connection + Bridge Interface        │    │
│  └──────────────────────────────────────────────┘    │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## Component Layers

### Layer 1: Smart Contracts (On-Chain)

The contracts are deployed on both chains and handle all on-chain logic.

```
┌─────────────────────────────────────────────────────┐
│                    BridgeRouter                      │
│        (User-facing entry point for bridging)       │
├─────────────────┬─────────────────┬─────────────────┤
│   BridgeVault   │ MessageVerifier │  WrappedToken   │
│ (Locks tokens)  │ (Proof verify)  │ (Mints wrapped) │
├─────────────────┴────────┬────────┴─────────────────┤
│                    ValidatorSet                      │
│          (Multi-sig signature verification)         │
└─────────────────────────────────────────────────────┘
```

**Contract Dependency Graph:**
- `BridgeRouter` depends on `BridgeVault`, `WrappedToken`, `MessageVerifier`
- `MessageVerifier` depends on `ValidatorSet`
- `BridgeVault` is standalone (controlled by Router/Validators)
- `WrappedToken` is standalone (controlled by Router)

### Layer 2: Relayer (Off-Chain)

The relayer is a Node.js TypeScript service that monitors events on both chains and triggers cross-chain actions.

```
┌────────────────────────────────────────────────┐
│                  RELAYER SERVICE                │
│                                                │
│  ┌──────────────┐      ┌───────────────────┐   │
│  │ BridgeListener│     │ BridgeExecutor    │   │
│  │ (Event Watch) │────►│ (TX Execution)    │   │
│  └──────────────┘      └───────────────────┘   │
│         │                        │              │
│  ┌──────┴────────┐      ┌───────┴───────┐      │
│  │ Sepolia RPC   │      │  Hoodi RPC    │      │
│  │ (WebSocket)   │      │  (WebSocket)  │      │
│  └───────────────┘      └───────────────┘      │
└────────────────────────────────────────────────┘
```

### Layer 3: Frontend (User Interface)

A Next.js React application with wallet connectivity.

```
┌────────────────────────────────────────────────┐
│                FRONTEND (Next.js)              │
│                                                │
│  ┌────────────┐ ┌───────────┐ ┌────────────┐  │
│  │ RainbowKit │ │   Wagmi   │ │   Viem     │  │
│  │(Wallet UI) │ │(React Web3│ │(Chain Ops) │  │
│  └────────────┘ └───────────┘ └────────────┘  │
└────────────────────────────────────────────────┘
```

## Data Flow

### Forward Bridge (Source → Destination)

```
User                Source Chain          Relayer           Dest Chain
 │                      │                   │                  │
 │──approve(vault)─────►│                   │                  │
 │──lockTokens()───────►│                   │                  │
 │                      │──TokensLocked────►│                  │
 │                      │                   │──completeBridge──►│
 │                      │                   │                  │──mint()──►User
 │                      │                   │                  │
```

### Reverse Bridge (Destination → Source)

```
User                Dest Chain           Relayer           Source Chain
 │                      │                   │                  │
 │──burnForBridge()────►│                   │                  │
 │                      │──TokensBurned────►│                  │
 │                      │                   │──releaseBridge──►│
 │                      │                   │                  │──transfer──►User
 │                      │                   │                  │
```

## State Management

### Nonce System

Every bridge operation has a unique nonce that:
1. Prevents replay attacks (same bridge executed twice)
2. Tracks lock/burn operations
3. Enables emergency withdrawal matching

```
Source Chain Nonces         Dest Chain Nonces
┌────────────────┐         ┌────────────────┐
│ Lock Nonce: 1  │────────►│ Processed: 1   │
│ Lock Nonce: 2  │────────►│ Processed: 2   │
│ Lock Nonce: 3  │ pending │                │
└────────────────┘         └────────────────┘
```

### Token Mapping

```
Source Chain                    Dest Chain
┌──────────────┐              ┌──────────────┐
│ TEST (ERC20) │◄────────────►│ wTEST (Wrap) │
│ 0x9f76...    │   1:1 peg    │ 0xabB8...    │
└──────────────┘              └──────────────┘
```

## Network Configuration

| Property | Sepolia | Hoodi |
|----------|---------|-------|
| Chain ID | 11155111 | 560048 |
| Role | Source (Lock) | Destination (Mint) |
| Contracts | Vault + Router | Router + WrappedToken |
| Explorer | sepolia.etherscan.io | explorer.hoodi.ethpandaops.io |

## Design Decisions

### Why Lock-and-Mint?

- **Simple**: Easy to understand and audit
- **Proven**: Used by major bridges (Wormhole, Multichain)
- **Secure**: Tokens are always backed 1:1
- **Reversible**: Users can always recover via emergency withdrawal

### Why Separate Contracts?

- **Single Responsibility**: Each contract does one thing well
- **Upgradeability**: Can replace one component without affecting others
- **Testability**: Each contract can be tested in isolation
- **Security**: Smaller contracts are easier to audit

### Why Off-Chain Relayer?

- **Gas Efficiency**: Only one on-chain transaction per bridge
- **Flexibility**: Easy to add new chains without contract changes
- **Speed**: Can process events faster than on-chain solutions
