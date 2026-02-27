// ============================================
// App - Root component with providers
// ============================================

import { RainbowKitProvider } from '@rainbow-me/rainbowkit';
import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useThemeProvider, ThemeContext } from './hooks';
import { BridgePage } from './pages';
import { config } from './config';
import '@rainbow-me/rainbowkit/styles.css';

const queryClient = new QueryClient();

function AppContent() {
  const theme = useThemeProvider();

  return (
    <ThemeContext.Provider value={theme}>
      <BridgePage />
    </ThemeContext.Provider>
  );
}

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          <AppContent />
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default App;
