/**
 * RainbowKit + Wagmi configuration
 * Only handles wallet connection setup
 */

import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http } from 'wagmi';
import { sepolia } from 'wagmi/chains';
import { phantomWallet, metaMaskWallet, coinbaseWallet, walletConnectWallet, rainbowWallet } from '@rainbow-me/rainbowkit/wallets';
import { hoodi } from './constants';

export const config = getDefaultConfig({
  appName: 'ChainBridge',
  projectId: 'e0d2e1e9c0b4f8a6d2c1b5a3f7e9d8c2',
  chains: [sepolia, hoodi],
  transports: {
    [sepolia.id]: http(),
    [hoodi.id]: http(),
  },
  wallets: [
    {
      groupName: 'Popular',
      wallets: [phantomWallet, metaMaskWallet, coinbaseWallet, rainbowWallet, walletConnectWallet],
    },
  ],
});
