/**
 * BRIDGE LISTENER - Listens for events on source chain
 */

import { ethers, Contract, Provider } from 'ethers';

// Vault ABI - we listen on the vault for TokensLocked events
const BRIDGE_VAULT_ABI = [
  "event TokensLocked(address indexed sender, address indexed token, uint256 amount, uint256 indexed destChainId, address recipient, uint256 nonce)"
];

export interface BridgeEvent {
  type: 'lock' | 'burn';
  sender: string;
  token: string;
  amount: bigint;
  destChainId: number;
  recipient: string;
  nonce: number;
  txHash: string;
  blockNumber: number;
}

export class BridgeListener {
  private provider: Provider;
  private vaultContract: Contract;
  private processedEvents: Set<string> = new Set();

  constructor(rpcUrl: string, vaultAddress: string) {
    this.provider = new ethers.JsonRpcProvider(rpcUrl);
    this.vaultContract = new ethers.Contract(
      vaultAddress,
      BRIDGE_VAULT_ABI,
      this.provider
    );
    console.log(`📋 Listening to Vault at: ${vaultAddress}`);
  }

  /**
   * Start listening for TokensLocked events
   */
  async startListening(callback: (event: BridgeEvent) => Promise<void>): Promise<void> {
    console.log('🎧 Listening for TokensLocked events...');

    this.vaultContract.on(
      'TokensLocked',
      async (sender, token, amount, destChainId, recipient, nonce, event) => {
        const eventId = `${event.log.transactionHash}-${nonce}`;
        
        if (this.processedEvents.has(eventId)) return;
        this.processedEvents.add(eventId);

        console.log(`\n📦 New TokensLocked event detected!`);
        console.log(`   Tx: ${event.log.transactionHash}`);
        console.log(`   From: ${sender}`);
        console.log(`   Token: ${token}`);
        console.log(`   Amount: ${ethers.formatUnits(amount, 18)}`);
        console.log(`   To Chain: ${destChainId}`);
        console.log(`   Recipient: ${recipient}`);
        console.log(`   Nonce: ${nonce}`);

        await callback({
          type: 'lock',
          sender,
          token,
          amount,
          destChainId: Number(destChainId),
          recipient,
          nonce: Number(nonce),
          txHash: event.log.transactionHash,
          blockNumber: event.log.blockNumber,
        });
      }
    );
  }

  /**
   * Wait for confirmations
   */
  async waitForConfirmations(txHash: string, confirmations: number): Promise<boolean> {
    console.log(`⏳ Waiting for ${confirmations} confirmations...`);
    
    const receipt = await this.provider.getTransactionReceipt(txHash);
    if (!receipt) return false;

    const currentBlock = await this.provider.getBlockNumber();
    const confirms = currentBlock - receipt.blockNumber;
    
    if (confirms >= confirmations) {
      console.log(`✅ ${confirms} confirmations received`);
      return true;
    }

    // Wait and check again
    await new Promise(r => setTimeout(r, 5000));
    return this.waitForConfirmations(txHash, confirmations);
  }

  async getCurrentBlock(): Promise<number> {
    return await this.provider.getBlockNumber();
  }
}
