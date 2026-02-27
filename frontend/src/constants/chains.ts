// ============================================
// Chain configurations
// ============================================

import { sepolia } from 'wagmi/chains';

export const hoodi = {
  id: 560048,
  name: 'Hoodi',
  nativeCurrency: { decimals: 18, name: 'Ether', symbol: 'ETH' },
  rpcUrls: { default: { http: ['https://rpc.hoodi.ethpandaops.io'] } },
  blockExplorers: { default: { name: 'Explorer', url: 'https://explorer.hoodi.ethpandaops.io' } },
  testnet: true,
} as const;

export const CHAIN_CONFIG = {
  forward: {
    source: { name: 'Sepolia', chainId: sepolia.id, explorer: 'https://sepolia.etherscan.io' },
    dest: { name: 'Hoodi', chainId: hoodi.id, explorer: 'https://explorer.hoodi.ethpandaops.io' },
    symbol: 'TEST',
    receiveSymbol: 'wTEST',
  },
  reverse: {
    source: { name: 'Hoodi', chainId: hoodi.id, explorer: 'https://explorer.hoodi.ethpandaops.io' },
    dest: { name: 'Sepolia', chainId: sepolia.id, explorer: 'https://sepolia.etherscan.io' },
    symbol: 'wTEST',
    receiveSymbol: 'TEST',
  },
} as const;

export { sepolia };
