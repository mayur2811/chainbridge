// ============================================
// Bridge Page - Composes all bridge components
// ============================================

import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useTheme, useBridge } from '../hooks';
import {
  Header,
  DirectionToggle,
  NetworkWarning,
  TokenInput,
  ConfirmModal,
  TransactionProgress,
  TransactionResult,
  FAQ,
  ContractInfo,
} from '../components';

export function BridgePage() {
  const { darkMode, bgClass, cardClass, textClass, subTextClass, inputBgClass } = useTheme();
  const bridge = useBridge();

  return (
    <div className={`min-h-screen ${bgClass} transition-colors duration-300`}>
      <Header />

      <main className="max-w-lg mx-auto px-4 sm:px-6 py-8 sm:py-12">
        <div className={`${cardClass} rounded-2xl shadow-sm border p-4 sm:p-6 transition-all duration-200`}>

          {/* Confirmation Modal */}
          {bridge.step === 'confirming' && (
            <ConfirmModal
              amount={bridge.amount}
              symbol={bridge.chainConfig.symbol}
              sourceChain={bridge.chainConfig.source.name}
              destChain={bridge.chainConfig.dest.name}
              recipient=""
              useCustomRecipient={bridge.useCustomRecipient}
              customRecipient={bridge.recipient}
              onConfirm={bridge.handleBridge}
              onCancel={() => bridge.resetState()}
            />
          )}

          {/* Success */}
          {bridge.step === 'success' && (
            <TransactionResult
              type="success"
              destChain={bridge.chainConfig.dest.name}
              txHash={bridge.txHash}
              explorerUrl={bridge.explorerUrl}
              onReset={bridge.resetState}
            />
          )}

          {/* Error */}
          {bridge.step === 'error' && (
            <TransactionResult
              type="error"
              message={bridge.errorMsg}
              onReset={bridge.resetState}
            />
          )}

          {/* Processing */}
          {(bridge.step === 'approving' || bridge.step === 'bridging' || bridge.step === 'waiting') && (
            <TransactionProgress
              step={bridge.step}
              txHash={bridge.txHash}
              explorerUrl={bridge.explorerUrl}
            />
          )}

          {/* Normal Form */}
          {bridge.step === 'idle' && (
            <>
              <div className="text-center mb-6">
                <h2 className={`text-xl font-bold ${textClass}`}>Bridge Tokens</h2>
                <p className={`${subTextClass} mt-1 text-sm`}>Transfer tokens between networks</p>
              </div>

              <DirectionToggle
                direction={bridge.direction}
                onChange={bridge.setDirection}
              />

              {bridge.isWrongNetwork && (
                <NetworkWarning
                  chainName={bridge.chainConfig.source.name}
                  onSwitch={bridge.handleSwitchNetwork}
                />
              )}

              {/* From input */}
              <TokenInput
                label="From"
                chainName={bridge.chainConfig.source.name}
                symbol={bridge.chainConfig.symbol}
                amount={bridge.amount}
                balance={bridge.formattedBalance}
                isLoading={bridge.isLoadingBalance}
                onAmountChange={bridge.setAmount}
                onPercentage={bridge.setPercentage}
              />

              {/* Arrow separator */}
              <div className="flex justify-center py-2">
                <div className={`w-10 h-10 ${
                  darkMode ? 'bg-slate-800' : 'bg-slate-100'
                } rounded-full flex items-center justify-center border-4 ${
                  darkMode ? 'border-slate-900' : 'border-white'
                } shadow-sm`}>
                  <svg className={`w-5 h-5 ${subTextClass}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 14l-7 7m0 0l-7-7m7 7V3" />
                  </svg>
                </div>
              </div>

              {/* To output */}
              <TokenInput
                label="To"
                chainName={bridge.chainConfig.dest.name}
                symbol={bridge.chainConfig.receiveSymbol}
                amount={bridge.amount}
                readOnly
              />

              {/* Custom recipient */}
              <div className="mt-4 mb-6">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={bridge.useCustomRecipient}
                    onChange={(e) => bridge.setUseCustomRecipient(e.target.checked)}
                    className="w-4 h-4 rounded border-slate-300 text-blue-600 focus:ring-blue-500"
                  />
                  <span className={`text-sm ${subTextClass}`}>Send to different address</span>
                </label>
                {bridge.useCustomRecipient && (
                  <input
                    type="text"
                    placeholder="0x..."
                    value={bridge.recipient}
                    onChange={(e) => bridge.setRecipient(e.target.value)}
                    className={`mt-2 w-full px-3 py-2.5 rounded-lg ${inputBgClass} border ${textClass} text-sm font-mono outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/20 transition-all`}
                  />
                )}
              </div>

              {/* Action button */}
              {!bridge.isConnected ? (
                <ConnectButton.Custom>
                  {({ openConnectModal }) => (
                    <button
                      onClick={openConnectModal}
                      className="w-full py-4 bg-blue-600 text-white font-semibold rounded-xl hover:bg-blue-700 transition-all shadow-lg shadow-blue-600/20"
                    >
                      Connect Wallet
                    </button>
                  )}
                </ConnectButton.Custom>
              ) : bridge.isWrongNetwork ? (
                <button
                  onClick={bridge.handleSwitchNetwork}
                  className="w-full py-4 bg-amber-500 text-white font-semibold rounded-xl hover:bg-amber-600 transition-all"
                >
                  Switch to {bridge.chainConfig.source.name}
                </button>
              ) : (
                <button
                  onClick={bridge.showConfirmation}
                  disabled={!bridge.amount || parseFloat(bridge.amount) <= 0}
                  className="w-full py-4 bg-blue-600 text-white font-semibold rounded-xl hover:bg-blue-700 disabled:bg-slate-300 disabled:cursor-not-allowed transition-all shadow-lg shadow-blue-600/20 disabled:shadow-none"
                >
                  Bridge Tokens
                </button>
              )}
            </>
          )}
        </div>

        <FAQ />
        <ContractInfo />

        <p className={`text-center mt-4 text-xs ${subTextClass}`}>
          Testnet Demo - Not Audited
        </p>
      </main>
    </div>
  );
}
