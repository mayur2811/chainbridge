/**
 * BRIDGE EXECUTOR - Executes transactions on destination chain
 */

import { ethers, Contract, Wallet, Provider } from 'ethers';
import { BRIDGE_ROUTER_ABI } from './abis';
import { BridgeEvent } from './bridge-listener';

export class BridgeExecutor {
  private provider: Provider;
  private wallet: Wallet;
  private routerContract: Contract;
  private sourceChainId: number;

  constructor(
    rpcUrl: string,
    routerAddress: string,
    privateKey: string,
    sourceChainId: number
  ) {
    this.provider = new ethers.JsonRpcProvider(rpcUrl);
    this.wallet = new ethers.Wallet(privateKey, this.provider);
    this.routerContract = new ethers.Contract(
      routerAddress,
      BRIDGE_ROUTER_ABI,
      this.wallet
    );
    this.sourceChainId = sourceChainId;

    console.log(`🔑 Relayer address: ${this.wallet.address}`);
  }

  /**
   * Complete bridge by minting wrapped tokens
   */
  async completeBridge(event: BridgeEvent): Promise<string> {
    console.log(`\n🚀 Executing completeBridge on destination chain...`);

    // Check if already processed
    const isProcessed = await this.routerContract.isProcessed(
      this.sourceChainId,
      event.nonce
    );

    if (isProcessed) {
      console.log(`⚠️ Event already processed, skipping`);
      return '';
    }

    try {
      const tx = await this.routerContract.completeBridge(
        event.token,      // originalToken
        event.recipient,  // recipient
        event.amount,     // amount
        this.sourceChainId, // sourceChainId
        event.nonce       // nonce
      );

      console.log(`📤 Transaction sent: ${tx.hash}`);
      
      const receipt = await tx.wait();
      console.log(`✅ Bridge completed! Gas used: ${receipt.gasUsed}`);

      return tx.hash;
    } catch (error: any) {
      console.error(`❌ Error completing bridge: ${error.message}`);
      throw error;
    }
  }

  /**
   * Release original tokens (for reverse bridge)
   */
  async releaseBridge(event: BridgeEvent): Promise<string> {
    console.log(`\n🔓 Executing releaseBridge on source chain...`);

    try {
      const tx = await this.routerContract.releaseBridge(
        event.token,
        event.recipient,
        event.amount,
        event.destChainId, // source of the burn
        event.nonce
      );

      console.log(`📤 Transaction sent: ${tx.hash}`);
      
      const receipt = await tx.wait();
      console.log(`✅ Tokens released! Gas used: ${receipt.gasUsed}`);

      return tx.hash;
    } catch (error: any) {
      console.error(`❌ Error releasing tokens: ${error.message}`);
      throw error;
    }
  }

  getAddress(): string {
    return this.wallet.address;
  }
}
