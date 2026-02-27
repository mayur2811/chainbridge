// ============================================
// Shared TypeScript types for the bridge app
// ============================================

/** Bridge transaction step states */
export type Step = 'idle' | 'confirming' | 'approving' | 'bridging' | 'waiting' | 'success' | 'error';

/** Bridge direction */
export type Direction = 'forward' | 'reverse';

/** Theme mode */
export type ThemeMode = 'light' | 'dark';

/** Theme context shape */
export interface ThemeContextType {
  darkMode: boolean;
  toggleDarkMode: () => void;
  bgClass: string;
  cardClass: string;
  textClass: string;
  subTextClass: string;
  inputBgClass: string;
}

/** Bridge state for the useBridge hook */
export interface BridgeState {
  amount: string;
  recipient: string;
  useCustomRecipient: boolean;
  direction: Direction;
  step: Step;
  txHash: string;
  errorMsg: string;
}

/** Chain info for display */
export interface ChainInfo {
  name: string;
  chainId: number;
  explorerUrl: string;
}
