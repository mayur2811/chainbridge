/**
 * ============================================
 * CHAINBRIDGE RELAYER - CONFIGURATION
 * ============================================
 * 
 * This file loads and validates configuration from environment variables.
 * 
 * WHY SEPARATE CONFIG FILE?
 * 1. Centralized configuration management
 * 2. Type safety for config values
 * 3. Validation at startup (fail fast!)
 * 4. Easy to add new config options
 */

import dotenv from 'dotenv';

// Load .env file
dotenv.config();

/**
 * Chain configuration interface
 */
export interface ChainConfig {
  chainId: number;
  rpcUrl: string;
  vaultAddress?: string;    // Only on source chain
  routerAddress: string;
  wrappedTokenAddress?: string; // Only on dest chain
}

/**
 * Full relayer configuration
 */
export interface RelayerConfig {
  privateKey: string;
  sourceChain: ChainConfig;
  destChain: ChainConfig;
  confirmationBlocks: number;
  pollIntervalMs: number;
  logLevel: string;
}

/**
 * Get required environment variable (throws if missing)
 */
function getEnvRequired(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

/**
 * Get optional environment variable with default
 */
function getEnvOptional(key: string, defaultValue: string): string {
  return process.env[key] || defaultValue;
}

/**
 * Load and validate configuration
 */
export function loadConfig(): RelayerConfig {
  console.log('📋 Loading configuration...');

  const config: RelayerConfig = {
    // Private key for signing transactions
    privateKey: getEnvRequired('RELAYER_PRIVATE_KEY'),

    // Source chain (where tokens are locked)
    sourceChain: {
      chainId: parseInt(getEnvRequired('SOURCE_CHAIN_ID')),
      rpcUrl: getEnvRequired('SOURCE_CHAIN_RPC'),
      vaultAddress: getEnvOptional('SOURCE_VAULT_ADDRESS', ''),
      routerAddress: getEnvRequired('SOURCE_ROUTER_ADDRESS'),
    },

    // Destination chain (where tokens are minted)
    destChain: {
      chainId: parseInt(getEnvRequired('DEST_CHAIN_ID')),
      rpcUrl: getEnvRequired('DEST_CHAIN_RPC'),
      routerAddress: getEnvRequired('DEST_ROUTER_ADDRESS'),
      wrappedTokenAddress: getEnvOptional('DEST_WRAPPED_TOKEN_ADDRESS', ''),
    },

    // Relayer settings
    confirmationBlocks: parseInt(getEnvOptional('CONFIRMATION_BLOCKS', '3')),
    pollIntervalMs: parseInt(getEnvOptional('POLL_INTERVAL_MS', '5000')),
    logLevel: getEnvOptional('LOG_LEVEL', 'info'),
  };

  // Validate config
  validateConfig(config);

  console.log('✅ Configuration loaded successfully');
  console.log(`   Source Chain: ${config.sourceChain.chainId}`);
  console.log(`   Dest Chain: ${config.destChain.chainId}`);
  console.log(`   Confirmations: ${config.confirmationBlocks}`);

  return config;
}

/**
 * Validate configuration values
 */
function validateConfig(config: RelayerConfig): void {
  // Check private key format
  if (!config.privateKey.startsWith('0x') || config.privateKey.length !== 66) {
    throw new Error('Invalid private key format. Must be 0x + 64 hex characters');
  }

  // Check chain IDs
  if (config.sourceChain.chainId === config.destChain.chainId) {
    throw new Error('Source and destination chains must be different');
  }

  // Check RPC URLs
  if (!config.sourceChain.rpcUrl.startsWith('http')) {
    throw new Error('Invalid source chain RPC URL');
  }
  if (!config.destChain.rpcUrl.startsWith('http')) {
    throw new Error('Invalid destination chain RPC URL');
  }
}

// Export default config instance
export const config = loadConfig();
