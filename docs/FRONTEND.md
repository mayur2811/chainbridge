# Frontend Documentation

## Overview

The ChainBridge frontend is a Next.js 14 application built with TypeScript that provides a professional, user-friendly interface for bridging tokens between Sepolia and Hoodi testnets.

## Tech Stack

| Technology   | Purpose                         |
| ------------ | ------------------------------- |
| Next.js 14   | React framework with App Router |
| TypeScript   | Type-safe development           |
| Tailwind CSS | Utility-first styling           |
| RainbowKit   | Wallet connection UI            |
| Wagmi        | React hooks for Ethereum        |
| Viem         | Blockchain interaction library  |

## Project Structure

```
frontend/
├── src/
│   └── app/
│       ├── config.ts       # Contract addresses, ABIs, chain config
│       ├── globals.css      # Global styles
│       ├── layout.tsx       # Root layout with Providers wrapper
│       ├── page.tsx         # Main bridge interface
│       └── providers.tsx    # Web3 provider setup
├── next.config.ts
├── package.json
├── postcss.config.mjs
└── tsconfig.json
```

## File Details

### config.ts

Central configuration file containing:

- Contract addresses for both chains
- ABI definitions for Vault, Token, and WrappedToken
- Hoodi custom chain definition
- RainbowKit configuration with wallet list

**Supported Wallets:**

- Phantom
- MetaMask
- Coinbase Wallet
- Rainbow
- WalletConnect

### providers.tsx

Sets up the Web3 provider hierarchy:

```
WagmiProvider (blockchain connection)
  └── QueryClientProvider (data caching)
       └── RainbowKitProvider (wallet UI)
```

### page.tsx

Main bridge interface with the following states:

| State        | Description                       |
| ------------ | --------------------------------- |
| `idle`       | Default form state                |
| `confirming` | Confirmation modal shown          |
| `approving`  | Token approval in progress        |
| `bridging`   | Lock/burn transaction in progress |
| `waiting`    | Waiting for bridge confirmation   |
| `success`    | Bridge completed                  |
| `error`      | Transaction failed                |

### layout.tsx

Root layout with:

- Font configuration
- SEO metadata
- Providers wrapper

## UI Features

### Bridge Form

- Direction toggle (Sepolia → Hoodi / Hoodi → Sepolia)
- Amount input with percentage buttons (25%, 50%, 75%, 100%)
- Real-time balance display with skeleton loader
- Token symbol display

### Wallet Connection

- Multi-wallet support via RainbowKit
- Network auto-detection and switching
- Wrong network warning with switch button

### Transaction Flow

- Confirmation modal before bridging
- 3-step progress indicator (Approve → Bridge → Confirm)
- Transaction hash with explorer link
- Success animation with "View on Explorer" link

### User Preferences

- Dark/Light mode toggle (persisted in localStorage)
- Custom recipient address option

### Error Handling

- Specific error messages (Insufficient balance, Rejected, etc.)
- Retry button on failure

### Additional

- FAQ section (expandable)
- Contract addresses display with explorer links
- "Testnet Demo - Not Audited" disclaimer
- Responsive design (mobile-friendly)

## Running Locally

```bash
cd frontend
npm install
npm run dev
```

Open http://localhost:3000

## Bridge Flow (User Perspective)

### Forward Bridge (Sepolia → Hoodi)

1. Connect wallet
2. Ensure on Sepolia network
3. Enter amount of TEST tokens
4. Click "Bridge Tokens"
5. Review confirmation modal → Click "Confirm"
6. Approve token spending in wallet (MetaMask popup)
7. Confirm lock transaction in wallet
8. Wait for bridge confirmation
9. Receive wTEST on Hoodi

### Reverse Bridge (Hoodi → Sepolia)

1. Switch to "Hoodi to Sepolia" tab
2. Ensure on Hoodi network
3. Enter amount of wTEST tokens
4. Click "Bridge Tokens"
5. Review confirmation → Click "Confirm"
6. Confirm burn transaction in wallet
7. Wait for bridge confirmation
8. Receive TEST on Sepolia

## Configuration Customization

To point the frontend to different contract addresses, edit `src/app/config.ts`:

```typescript
export const CONTRACTS = {
  sepolia: {
    vault: "0x...",
    router: "0x...",
    testToken: "0x...",
  },
  hoodi: {
    router: "0x...",
    wrappedToken: "0x...",
  },
};
```
