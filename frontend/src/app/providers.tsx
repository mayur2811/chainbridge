/**
 * ============================================
 * PROVIDERS WRAPPER COMPONENT
 * ============================================
 * 
 * 📚 WHAT THIS DOES:
 * - Wraps your entire app with Web3 functionality
 * - Makes wallet connection available everywhere
 * 
 * 📚 KEY CONCEPTS:
 * - Provider: Gives data/functionality to all child components
 * - WagmiProvider: Wallet & blockchain connection
 * - QueryClientProvider: Caches blockchain data
 * - RainbowKitProvider: Beautiful wallet connect modal
 */

'use client'; // This means the code runs in the browser, not server

import { RainbowKitProvider } from '@rainbow-me/rainbowkit';
import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { config } from './config';

// Import RainbowKit styles (gives us the pretty wallet modal)
import '@rainbow-me/rainbowkit/styles.css';

// Create a query client for caching
const queryClient = new QueryClient();

/**
 * 📚 WHAT IS A PROVIDER?
 * 
 * Think of it like giving everyone in a building access to WiFi.
 * Instead of setting up WiFi in each room, you set it up once
 * at the building level and everyone can use it.
 * 
 * Same idea here - we wrap the app once, and every component
 * can now connect to wallets and blockchains!
 */
export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          {children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
