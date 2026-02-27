// ============================================
// Contract addresses and ABIs
// ============================================

export const CONTRACTS = {
  sepolia: {
    chainId: 11155111,
    vault: '0xcD54697e22264a0c496606301ae19421c690f3dc' as `0x${string}`,
    router: '0xcF1C4C9ad85185ae346F71beCae1A92a41d857f5' as `0x${string}`,
    testToken: '0x9f76259FF348362e23753815d351c5F4177b77B7' as `0x${string}`,
  },
  hoodi: {
    chainId: 560048,
    router: '0xcF1C4C9ad85185ae346F71beCae1A92a41d857f5' as `0x${string}`,
    wrappedToken: '0xabB81B91BE2B922E6059844ed844D5660b41A75f' as `0x${string}`,
  },
} as const;

export const VAULT_ABI = [
  {
    name: 'lockTokens',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'token', type: 'address' },
      { name: 'amount', type: 'uint256' },
      { name: 'destChainId', type: 'uint256' },
      { name: 'recipient', type: 'address' },
    ],
    outputs: [],
  },
] as const;

export const TOKEN_ABI = [
  {
    name: 'approve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
] as const;

export const WRAPPED_TOKEN_ABI = [
  {
    name: 'burnForBridge',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'amount', type: 'uint256' },
      { name: 'recipient', type: 'address' },
    ],
    outputs: [],
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
] as const;
