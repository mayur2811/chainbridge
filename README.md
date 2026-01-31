# ChainBridge

A production-grade cross-chain token bridge enabling seamless ERC-20 token transfers between Ethereum networks.

## Overview

ChainBridge is a decentralized bridge protocol that allows users to transfer tokens between different blockchain networks. The system uses a lock-and-mint mechanism for forward bridging and burn-and-release for reverse bridging.

## Architecture

```
┌─────────────────┐         ┌─────────────────┐
│   Source Chain  │         │  Destination    │
│    (Sepolia)    │         │    (Hoodi)      │
├─────────────────┤         ├─────────────────┤
│  BridgeVault    │────────▶│  WrappedToken   │
│  (Lock tokens)  │         │  (Mint tokens)  │
├─────────────────┤         ├─────────────────┤
│  BridgeRouter   │◀───────▶│  BridgeRouter   │
│  (Entry point)  │         │  (Entry point)  │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │      ┌─────────────┐      │
         └─────▶│   Relayer   │◀─────┘
                │  (Off-chain) │
                └─────────────┘
```

## Features

- **Bidirectional Bridging**: Transfer tokens in both directions
- **Lock & Mint Mechanism**: Secure token locking with wrapped token minting
- **Multi-Validator Support**: Decentralized validation system
- **Emergency Controls**: Pause functionality and emergency withdrawal
- **Professional Frontend**: Modern React UI with wallet integration

## Tech Stack

| Component         | Technology                        |
| ----------------- | --------------------------------- |
| Smart Contracts   | Solidity, Foundry                 |
| Frontend          | Next.js, TypeScript, Tailwind CSS |
| Wallet Connection | RainbowKit, Wagmi                 |
| Relayer           | Node.js, TypeScript, ethers.js    |
| Testing           | Foundry (77 tests)                |

## Project Structure

```
chainbridge/
├── contracts/           # Smart contracts (Foundry)
│   ├── src/            # Contract source files
│   ├── test/           # Unit tests
│   └── script/         # Deployment scripts
├── frontend/           # Next.js frontend
│   └── src/app/        # React components
└── relayer/            # Off-chain relayer service
    └── src/            # TypeScript source
```

## Smart Contracts

| Contract              | Description                            |
| --------------------- | -------------------------------------- |
| `BridgeRouter.sol`    | Main entry point for bridge operations |
| `BridgeVault.sol`     | Locks tokens on source chain           |
| `WrappedToken.sol`    | ERC-20 wrapped tokens on destination   |
| `ValidatorSet.sol`    | Multi-signature validator management   |
| `MessageVerifier.sol` | Proof verification system              |

## Deployed Contracts

### Sepolia Testnet

- Vault: `0xcD54697e22264a0c496606301ae19421c690f3dc`
- Router: `0xcF1C4C9ad85185ae346F71beCae1A92a41d857f5`
- TEST Token: `0x9f76259FF348362e23753815d351c5F4177b77B7`

### Hoodi Testnet

- Router: `0xcF1C4C9ad85185ae346F71beCae1A92a41d857f5`
- wTEST Token: `0xabB81B91BE2B922E6059844ed844D5660b41A75f`

## Quick Start

### Prerequisites

- Node.js 18+
- Foundry
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/chainbridge.git
cd chainbridge

# Install contract dependencies
cd contracts
forge install

# Install frontend dependencies
cd ../frontend
npm install

# Install relayer dependencies
cd ../relayer
npm install
```

### Run Tests

```bash
cd contracts
forge test
```

### Start Development

```bash
# Terminal 1: Start frontend
cd frontend
npm run dev

# Terminal 2: Start relayer
cd relayer
npm run dev
```

## How It Works

### Forward Bridge (Sepolia → Hoodi)

1. User approves tokens for the Vault contract
2. User calls `lockTokens()` on the Vault
3. Relayer detects `TokensLocked` event
4. Relayer calls `completeBridge()` on destination Router
5. Wrapped tokens are minted to the user

### Reverse Bridge (Hoodi → Sepolia)

1. User calls `burnForBridge()` on wrapped token
2. Relayer detects `TokensBurned` event
3. Relayer calls `releaseBridge()` on source Router
4. Original tokens are released to the user

## Security Features

- ReentrancyGuard on all state-changing functions
- Pausable contracts for emergency situations
- Nonce-based replay protection
- Multi-validator consensus support
- Emergency withdrawal mechanism

## Testing

The project includes 77 comprehensive unit tests covering:

- Token locking and unlocking
- Wrapped token minting and burning
- Access control
- Edge cases and error conditions

```bash
forge test -vv
```

## Frontend Features

- Wallet connection (MetaMask, Phantom, etc.)
- Dark/Light mode toggle
- Transaction progress tracking
- Network auto-detection
- Custom recipient addresses
- FAQ section

## License

MIT

## Author

Built as a portfolio project demonstrating full-stack blockchain development skills.
