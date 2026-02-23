# Deployment Guide

## Overview

This guide covers deploying ChainBridge to any two EVM-compatible chains. The current deployment targets Sepolia and Hoodi testnets.

## Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- Node.js 18+
- Private key with ETH on both chains
- RPC URLs for both chains

## Deployment Order

Contracts must be deployed in a specific order due to dependencies:

```
Step 1: Deploy on Source Chain (Sepolia)
   ├── 1a. TEST Token (ERC-20)
   ├── 1b. BridgeVault
   └── 1c. BridgeRouter

Step 2: Deploy on Destination Chain (Hoodi)
   ├── 2a. BridgeRouter
   └── 2b. WrappedToken (wTEST)

Step 3: Configuration
   ├── 3a. Register wrapped token on Hoodi Router
   ├── 3b. Add relayer as validator on both chains
   ├── 3c. Add supported token on Vault
   └── 3d. Set bridge address on WrappedToken

Step 4: Deploy Relayer
   └── Configure and start relayer service

Step 5: Deploy Frontend
   └── Configure contract addresses
```

## Step 1: Source Chain Deployment (Sepolia)

### Environment Setup

```bash
cd contracts

# Create .env file
cp .env.example .env
```

Edit `.env`:

```env
PRIVATE_KEY=0x_YOUR_PRIVATE_KEY
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
HOODI_RPC_URL=https://rpc.hoodi.ethpandaops.io
```

### Deploy

```bash
forge script script/DeployBridge.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify
```

This deploys:

- TEST Token
- BridgeVault
- BridgeRouter

Save the deployed addresses.

## Step 2: Destination Chain Deployment (Hoodi)

```bash
forge script script/DeployHoodi.s.sol \
    --rpc-url $HOODI_RPC_URL \
    --broadcast
```

This deploys:

- BridgeRouter (on Hoodi)
- WrappedToken (wTEST)

## Step 3: Configuration

### Register Wrapped Token

```bash
forge script script/RegisterWrappedToken.s.sol \
    --rpc-url $HOODI_RPC_URL \
    --broadcast
```

### Add Validator

The relayer wallet must be registered as a validator on both chains:

**On Sepolia Vault:**

```solidity
vault.addValidator(relayerAddress);
```

**On Hoodi Router:**

```solidity
router.addValidator(relayerAddress);
```

### Add Supported Token

```solidity
vault.addSupportedToken(testTokenAddress);
```

### Set Bridge on WrappedToken

```solidity
wrappedToken.setBridge(hoodiRouterAddress);
```

## Step 4: Relayer Setup

```bash
cd relayer

# Install dependencies
npm install

# Create .env file
cp .env.example .env
```

Edit `.env`:

```env
PRIVATE_KEY=0x_RELAYER_PRIVATE_KEY
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
HOODI_RPC_URL=https://rpc.hoodi.ethpandaops.io
```

Update contract addresses in `src/config.ts` if different from defaults.

```bash
# Start relayer
npm run dev
```

## Step 5: Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Update contract addresses in src/app/config.ts

# Start development server
npm run dev
```

## Current Deployed Addresses

### Sepolia (Chain ID: 11155111)

| Contract     | Address                                      |
| ------------ | -------------------------------------------- |
| TEST Token   | `0x9f76259FF348362e23753815d351c5F4177b77B7` |
| BridgeVault  | `0xcD54697e22264a0c496606301ae19421c690f3dc` |
| BridgeRouter | `0xcF1C4C9ad85185ae346F71beCae1A92a41d857f5` |

### Hoodi (Chain ID: 560048)

| Contract     | Address                                      |
| ------------ | -------------------------------------------- |
| BridgeRouter | `0xcF1C4C9ad85185ae346F71beCae1A92a41d857f5` |
| wTEST Token  | `0xabB81B91BE2B922E6059844ed844D5660b41A75f` |

### Relayer

| Property | Value                                        |
| -------- | -------------------------------------------- |
| Address  | `0x2b4446A700201Febe798745FdB4A4Ab476f75E26` |
| Role     | Validator on both chains                     |

## Verification

### Verify Contracts

```bash
forge verify-contract <ADDRESS> <CONTRACT_NAME> \
    --chain-id 11155111 \
    --etherscan-api-key <KEY>
```

### Test Bridge

```bash
# Forward bridge test
forge script script/TestBridge.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast

# Reverse bridge test
forge script script/TestReverseBridge.s.sol --rpc-url $HOODI_RPC_URL --broadcast
```

## Adding New Chains

To add a new destination chain:

1. Deploy BridgeRouter and WrappedToken on the new chain
2. Register the wrapped token mapping
3. Add relayer as validator
4. Update relayer config with new chain RPC and addresses
5. Add chain configuration to frontend

The contracts are chain-agnostic - the same code works on any EVM chain.

## Troubleshooting

| Issue                  | Solution                                                  |
| ---------------------- | --------------------------------------------------------- |
| "Token not supported"  | Call `vault.addSupportedToken(tokenAddress)`              |
| "Not a validator"      | Register relayer: `vault.addValidator(address)`           |
| "Already processed"    | Nonce already used, check for duplicate transactions      |
| Relayer not responding | Check RPC URLs, private key balance, and logs             |
| Frontend won't connect | Verify chain IDs match and contract addresses are correct |
