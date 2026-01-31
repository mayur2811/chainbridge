/**
 * ============================================
 * CHAINBRIDGE RELAYER - BIDIRECTIONAL
 * ============================================
 * 
 * Handles BOTH directions:
 * - Sepolia → Hoodi (TokensLocked → completeBridge)
 * - Hoodi → Sepolia (TokensBurned → releaseBridge)
 */

import dotenv from 'dotenv';
dotenv.config();

import { ethers, Contract, Provider, Wallet } from 'ethers';

// ABIs for events
const VAULT_ABI = [
  "event TokensLocked(address indexed sender, address indexed token, uint256 amount, uint256 indexed destChainId, address recipient, uint256 nonce)"
];

const WRAPPED_TOKEN_ABI = [
  "event TokensBurned(address indexed burner, uint256 amount, uint256 indexed destChainId, address indexed recipient, uint256 nonce)"
];

const ROUTER_ABI = [
  "function completeBridge(address originalToken, address recipient, uint256 amount, uint256 sourceChainId, uint256 nonce) external",
  "function releaseBridge(address token, address recipient, uint256 amount, uint256 sourceChainId, uint256 nonce) external",
  "function isProcessed(uint256 sourceChainId, uint256 nonce) view returns (bool)"
];

// Config
const config = {
  privateKey: process.env.RELAYER_PRIVATE_KEY!,
  sepolia: {
    chainId: 11155111,
    rpc: process.env.SOURCE_CHAIN_RPC!,
    vault: process.env.SOURCE_VAULT_ADDRESS!,
    router: process.env.SOURCE_ROUTER_ADDRESS!,
  },
  hoodi: {
    chainId: 560048,
    rpc: process.env.DEST_CHAIN_RPC!,
    router: process.env.DEST_ROUTER_ADDRESS!,
    wrappedToken: '0xabB81B91BE2B922E6059844ed844D5660b41A75f', // wTEST
  },
  originalToken: '0x9f76259FF348362e23753815d351c5F4177b77B7', // TEST on Sepolia
  confirmations: 2,
};

async function main() {
  console.log('');
  console.log('╔════════════════════════════════════════════════╗');
  console.log('║  🌉 CHAINBRIDGE RELAYER v2.0 - BIDIRECTIONAL   ║');
  console.log('╚════════════════════════════════════════════════╝');
  console.log('');

  // Setup providers and wallets
  const sepoliaProvider = new ethers.JsonRpcProvider(config.sepolia.rpc);
  const hoodiProvider = new ethers.JsonRpcProvider(config.hoodi.rpc);
  
  const sepoliaWallet = new ethers.Wallet(config.privateKey, sepoliaProvider);
  const hoodiWallet = new ethers.Wallet(config.privateKey, hoodiProvider);
  
  console.log(`🔑 Relayer: ${sepoliaWallet.address}`);
  console.log('');

  // Setup contracts
  const sepoliaVault = new ethers.Contract(config.sepolia.vault, VAULT_ABI, sepoliaProvider);
  const sepoliaRouter = new ethers.Contract(config.sepolia.router, ROUTER_ABI, sepoliaWallet);
  const hoodiRouter = new ethers.Contract(config.hoodi.router, ROUTER_ABI, hoodiWallet);
  const wrappedToken = new ethers.Contract(config.hoodi.wrappedToken, WRAPPED_TOKEN_ABI, hoodiProvider);

  console.log('📋 Listening on:');
  console.log(`   Sepolia Vault: ${config.sepolia.vault}`);
  console.log(`   Hoodi wTEST: ${config.hoodi.wrappedToken}`);
  console.log('─'.repeat(50));

  // ============================================
  // DIRECTION 1: Sepolia → Hoodi (Lock → Mint)
  // ============================================
  console.log('🎧 [Sepolia→Hoodi] Listening for TokensLocked...');
  
  sepoliaVault.on('TokensLocked', async (sender, token, amount, destChainId, recipient, nonce, event) => {
    console.log(`\n📦 [Sepolia] TokensLocked detected!`);
    console.log(`   Token: ${token}`);
    console.log(`   Amount: ${ethers.formatUnits(amount, 18)}`);
    console.log(`   To: ${recipient}`);
    console.log(`   Nonce: ${nonce}`);

    // Wait for confirmations
    console.log(`⏳ Waiting for confirmations...`);
    await waitForConfirmations(sepoliaProvider, event.log.transactionHash, config.confirmations);

    // Call completeBridge on Hoodi
    try {
      console.log(`🚀 Calling completeBridge on Hoodi...`);
      const tx = await hoodiRouter.completeBridge(
        token,
        recipient,
        amount,
        config.sepolia.chainId,
        nonce
      );
      console.log(`📤 Tx sent: ${tx.hash}`);
      const receipt = await tx.wait();
      console.log(`✅ Bridge completed! Gas: ${receipt.gasUsed}`);
    } catch (error: any) {
      console.log(`❌ Error: ${error.shortMessage || error.message}`);
    }
    console.log('─'.repeat(50));
  });

  // ============================================
  // DIRECTION 2: Hoodi → Sepolia (Burn → Release)
  // ============================================
  console.log('🎧 [Hoodi→Sepolia] Listening for TokensBurned...');
  
  wrappedToken.on('TokensBurned', async (burner, amount, destChainId, recipient, nonce, event) => {
    console.log(`\n🔥 [Hoodi] TokensBurned detected!`);
    console.log(`   Burner: ${burner}`);
    console.log(`   Amount: ${ethers.formatUnits(amount, 18)}`);
    console.log(`   DestChain: ${destChainId}`);
    console.log(`   Recipient: ${recipient}`);
    console.log(`   Nonce: ${nonce}`);

    // Wait for confirmations
    console.log(`⏳ Waiting for confirmations...`);
    await waitForConfirmations(hoodiProvider, event.log.transactionHash, config.confirmations);

    // Call releaseBridge on Sepolia
    try {
      console.log(`🚀 Calling releaseBridge on Sepolia...`);
      const tx = await sepoliaRouter.releaseBridge(
        config.originalToken,
        recipient,
        amount,
        config.hoodi.chainId,
        nonce
      );
      console.log(`📤 Tx sent: ${tx.hash}`);
      const receipt = await tx.wait();
      console.log(`✅ Tokens released! Gas: ${receipt.gasUsed}`);
    } catch (error: any) {
      console.log(`❌ Error: ${error.shortMessage || error.message}`);
    }
    console.log('─'.repeat(50));
  });

  console.log('');
  console.log('🎯 Relayer ready! Watching both chains...');
  console.log('─'.repeat(50));
}

async function waitForConfirmations(provider: Provider, txHash: string, needed: number): Promise<void> {
  let confirms = 0;
  while (confirms < needed) {
    const receipt = await provider.getTransactionReceipt(txHash);
    if (receipt) {
      const current = await provider.getBlockNumber();
      confirms = current - receipt.blockNumber;
    }
    if (confirms < needed) {
      await new Promise(r => setTimeout(r, 5000));
    }
  }
  console.log(`✅ ${confirms} confirmations received`);
}

main().catch(console.error);
