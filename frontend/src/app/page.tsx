'use client';

import { useState, useEffect } from 'react';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount, useChainId, useSwitchChain, useWriteContract, useReadContract } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { CONTRACTS, VAULT_ABI, TOKEN_ABI, WRAPPED_TOKEN_ABI, hoodi } from './config';
import { sepolia } from 'wagmi/chains';

type Step = 'idle' | 'confirming' | 'approving' | 'bridging' | 'waiting' | 'success' | 'error';

export default function Home() {
  const [amount, setAmount] = useState('');
  const [recipient, setRecipient] = useState('');
  const [useCustomRecipient, setUseCustomRecipient] = useState(false);
  const [direction, setDirection] = useState<'forward' | 'reverse'>('forward');
  const [step, setStep] = useState<Step>('idle');
  const [txHash, setTxHash] = useState('');
  const [errorMsg, setErrorMsg] = useState('');
  const [darkMode, setDarkMode] = useState(false);
  const [showFaq, setShowFaq] = useState(false);

  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();
  const { writeContractAsync } = useWriteContract();

  const requiredChainId = direction === 'forward' ? sepolia.id : hoodi.id;
  const isWrongNetwork = isConnected && chainId !== requiredChainId;

  // Load dark mode preference
  useEffect(() => {
    const saved = localStorage.getItem('darkMode');
    if (saved) setDarkMode(saved === 'true');
  }, []);

  const toggleDarkMode = () => {
    setDarkMode(!darkMode);
    localStorage.setItem('darkMode', (!darkMode).toString());
  };

  const { data: testBalance, isLoading: testLoading } = useReadContract({
    address: CONTRACTS.sepolia.testToken,
    abi: TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    chainId: sepolia.id,
  });

  const { data: wrappedBalance, isLoading: wrappedLoading } = useReadContract({
    address: CONTRACTS.hoodi.wrappedToken,
    abi: TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    chainId: hoodi.id,
  });

  const showConfirmation = () => {
    if (!amount || parseFloat(amount) <= 0) return;
    setStep('confirming');
  };

  const handleBridge = async () => {
    if (!amount || !address) return;
    const recipientAddr = (useCustomRecipient && recipient) ? recipient as `0x${string}` : address;
    setTxHash('');
    setErrorMsg('');

    try {
      if (direction === 'forward') {
        setStep('approving');
        await writeContractAsync({
          address: CONTRACTS.sepolia.testToken,
          abi: TOKEN_ABI,
          functionName: 'approve',
          args: [CONTRACTS.sepolia.vault, parseEther(amount)],
          chainId: sepolia.id,
        });

        setStep('bridging');
        const hash = await writeContractAsync({
          address: CONTRACTS.sepolia.vault,
          abi: VAULT_ABI,
          functionName: 'lockTokens',
          args: [CONTRACTS.sepolia.testToken, parseEther(amount), BigInt(hoodi.id), recipientAddr],
          chainId: sepolia.id,
        });

        setTxHash(hash);
        setStep('waiting');
        setTimeout(() => setStep('success'), 3000);
      } else {
        setStep('bridging');
        const hash = await writeContractAsync({
          address: CONTRACTS.hoodi.wrappedToken,
          abi: WRAPPED_TOKEN_ABI,
          functionName: 'burnForBridge',
          args: [parseEther(amount), recipientAddr],
          chainId: hoodi.id,
        });

        setTxHash(hash);
        setStep('waiting');
        setTimeout(() => setStep('success'), 3000);
      }
    } catch (error: unknown) {
      setStep('error');
      const err = error as { shortMessage?: string; message?: string };
      const msg = err.shortMessage || err.message || '';
      if (msg.includes('insufficient')) setErrorMsg('Insufficient balance');
      else if (msg.includes('rejected') || msg.includes('denied')) setErrorMsg('Transaction rejected');
      else if (msg.includes('allowance')) setErrorMsg('Approval required first');
      else setErrorMsg(msg || 'Transaction failed');
    }
  };

  const handleSwitchNetwork = () => switchChain({ chainId: requiredChainId });
  const resetState = () => { setStep('idle'); setTxHash(''); setErrorMsg(''); setAmount(''); };

  const sourceChain = direction === 'forward' ? 'Sepolia' : 'Hoodi';
  const destChain = direction === 'forward' ? 'Hoodi' : 'Sepolia';
  const balance = direction === 'forward' ? testBalance : wrappedBalance;
  const isLoadingBalance = direction === 'forward' ? testLoading : wrappedLoading;
  const symbol = direction === 'forward' ? 'TEST' : 'wTEST';
  const explorerUrl = direction === 'forward' 
    ? `https://sepolia.etherscan.io/tx/${txHash}`
    : `https://explorer.hoodi.ethpandaops.io/tx/${txHash}`;

  const bgClass = darkMode ? 'bg-slate-900' : 'bg-slate-50';
  const cardClass = darkMode ? 'bg-slate-800 border-slate-700' : 'bg-white border-slate-200';
  const textClass = darkMode ? 'text-white' : 'text-slate-900';
  const subTextClass = darkMode ? 'text-slate-400' : 'text-slate-500';
  const inputBgClass = darkMode ? 'bg-slate-700 border-slate-600' : 'bg-slate-50 border-slate-100';

  return (
    <div className={`min-h-screen ${bgClass} transition-colors duration-300`}>
      {/* Header */}
      <header className={`${cardClass} border-b`}>
        <div className="max-w-6xl mx-auto px-4 sm:px-6 py-4 flex justify-between items-center">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center">
              <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
              </svg>
            </div>
            <span className={`text-xl font-semibold ${textClass}`}>ChainBridge</span>
          </div>
          <div className="flex items-center gap-3">
            {/* Dark Mode Toggle */}
            <button
              onClick={toggleDarkMode}
              className={`p-2 rounded-lg ${darkMode ? 'bg-slate-700 text-yellow-400' : 'bg-slate-100 text-slate-600'}`}
            >
              {darkMode ? (
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
                </svg>
              ) : (
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
                </svg>
              )}
            </button>
            <ConnectButton showBalance={false} />
          </div>
        </div>
      </header>

      {/* Main */}
      <main className="max-w-lg mx-auto px-4 sm:px-6 py-8 sm:py-12">
        <div className={`${cardClass} rounded-2xl shadow-sm border p-4 sm:p-6`}>
          
          {/* Confirmation Modal */}
          {step === 'confirming' && (
            <div className="py-6">
              <h3 className={`text-lg font-semibold ${textClass} text-center mb-4`}>Confirm Bridge</h3>
              <div className={`${inputBgClass} rounded-xl p-4 mb-4 border`}>
                <div className="flex justify-between mb-2">
                  <span className={subTextClass}>Amount</span>
                  <span className={`font-medium ${textClass}`}>{amount} {symbol}</span>
                </div>
                <div className="flex justify-between mb-2">
                  <span className={subTextClass}>From</span>
                  <span className={textClass}>{sourceChain}</span>
                </div>
                <div className="flex justify-between mb-2">
                  <span className={subTextClass}>To</span>
                  <span className={textClass}>{destChain}</span>
                </div>
                <div className="flex justify-between">
                  <span className={subTextClass}>Recipient</span>
                  <span className={`${textClass} text-sm font-mono`}>
                    {useCustomRecipient && recipient ? `${recipient.slice(0,6)}...${recipient.slice(-4)}` : 'Your wallet'}
                  </span>
                </div>
              </div>
              <div className="flex gap-3">
                <button
                  onClick={() => setStep('idle')}
                  className={`flex-1 py-3 rounded-xl font-medium ${darkMode ? 'bg-slate-700 text-white' : 'bg-slate-100 text-slate-700'}`}
                >
                  Cancel
                </button>
                <button
                  onClick={handleBridge}
                  className="flex-1 py-3 bg-blue-600 text-white font-medium rounded-xl hover:bg-blue-700"
                >
                  Confirm
                </button>
              </div>
            </div>
          )}

          {/* Success State */}
          {step === 'success' && (
            <div className="text-center py-8">
              <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4 animate-bounce">
                <svg className="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h3 className={`text-xl font-semibold ${textClass} mb-2`}>Bridge Successful</h3>
              <p className={`${subTextClass} mb-4`}>Tokens arriving on {destChain}</p>
              {txHash && (
                <a href={explorerUrl} target="_blank" rel="noopener noreferrer"
                   className="inline-flex items-center gap-1 text-blue-600 hover:text-blue-700 text-sm font-medium">
                  View on Explorer
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                  </svg>
                </a>
              )}
              <button onClick={resetState} className={`mt-6 w-full py-3 ${darkMode ? 'bg-slate-700' : 'bg-slate-100'} ${textClass} font-medium rounded-xl`}>
                Bridge More
              </button>
            </div>
          )}

          {/* Error State */}
          {step === 'error' && (
            <div className="text-center py-8">
              <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </div>
              <h3 className={`text-xl font-semibold ${textClass} mb-2`}>Transaction Failed</h3>
              <p className={`${subTextClass} mb-6`}>{errorMsg}</p>
              <button onClick={resetState} className="w-full py-3 bg-blue-600 text-white font-medium rounded-xl">
                Try Again
              </button>
            </div>
          )}

          {/* Processing States */}
          {(step === 'approving' || step === 'bridging' || step === 'waiting') && (
            <div className="py-8">
              <div className="flex justify-between mb-8">
                {['Approve', 'Bridge', 'Confirm'].map((label, i) => {
                  const stepIndex = step === 'approving' ? 0 : step === 'bridging' ? 1 : 2;
                  const isActive = i === stepIndex;
                  const isComplete = i < stepIndex;
                  return (
                    <div key={label} className="flex flex-col items-center flex-1">
                      <div className={`w-10 h-10 rounded-full flex items-center justify-center mb-2 transition-all duration-300 ${
                        isComplete ? 'bg-green-500' : isActive ? 'bg-blue-600' : darkMode ? 'bg-slate-700' : 'bg-slate-200'
                      }`}>
                        {isComplete ? (
                          <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                          </svg>
                        ) : isActive ? (
                          <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                        ) : (
                          <span className={subTextClass}>{i + 1}</span>
                        )}
                      </div>
                      <span className={`text-sm ${isActive ? 'text-blue-600 font-medium' : subTextClass}`}>{label}</span>
                    </div>
                  );
                })}
              </div>
              <p className={`text-center ${subTextClass}`}>
                {step === 'approving' && 'Approving tokens...'}
                {step === 'bridging' && 'Locking tokens...'}
                {step === 'waiting' && 'Confirming...'}
              </p>
              {txHash && (
                <div className="mt-4 text-center">
                  <a href={explorerUrl} target="_blank" className="text-blue-600 text-sm">View Transaction</a>
                </div>
              )}
            </div>
          )}

          {/* Normal Form */}
          {step === 'idle' && (
            <>
              <div className="text-center mb-6">
                <h2 className={`text-xl font-semibold ${textClass}`}>Bridge Tokens</h2>
                <p className={`${subTextClass} mt-1 text-sm`}>Transfer tokens between networks</p>
              </div>

              {/* Direction Toggle */}
              <div className={`flex ${darkMode ? 'bg-slate-700' : 'bg-slate-100'} rounded-xl p-1 mb-6`}>
                <button onClick={() => setDirection('forward')}
                  className={`flex-1 py-2.5 text-sm font-medium rounded-lg transition-all ${
                    direction === 'forward' ? `${cardClass} shadow-sm ${textClass}` : subTextClass
                  }`}>
                  Sepolia to Hoodi
                </button>
                <button onClick={() => setDirection('reverse')}
                  className={`flex-1 py-2.5 text-sm font-medium rounded-lg transition-all ${
                    direction === 'reverse' ? `${cardClass} shadow-sm ${textClass}` : subTextClass
                  }`}>
                  Hoodi to Sepolia
                </button>
              </div>

              {/* Network Warning */}
              {isWrongNetwork && (
                <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 mb-4">
                  <p className="text-amber-800 text-sm">Please switch to {sourceChain}</p>
                  <button onClick={handleSwitchNetwork}
                    className="mt-2 w-full py-2 bg-amber-100 text-amber-800 text-sm font-medium rounded-lg">
                    Switch Network
                  </button>
                </div>
              )}

              {/* From */}
              <div className={`${inputBgClass} rounded-xl p-4 mb-3 border`}>
                <div className="flex justify-between text-sm mb-2">
                  <span className={subTextClass}>From {sourceChain}</span>
                  <span className={subTextClass}>
                    Balance: {isLoadingBalance ? (
                      <span className="inline-block w-16 h-4 bg-slate-300 rounded animate-pulse" />
                    ) : (
                      <span className={`font-medium ${textClass}`}>{balance ? parseFloat(formatEther(balance)).toFixed(4) : '0.00'}</span>
                    )}
                  </span>
                </div>
                <div className="flex items-center gap-3">
                  <input type="number" placeholder="0.00" value={amount} onChange={(e) => setAmount(e.target.value)}
                    className={`flex-1 text-2xl font-medium ${textClass} bg-transparent outline-none placeholder-slate-400`} />
                  <div className={`${cardClass} border rounded-lg px-3 py-2`}>
                    <span className={`${textClass} font-medium text-sm`}>{symbol}</span>
                  </div>
                </div>
                <div className="flex gap-2 mt-3">
                  {['25', '50', '75', '100'].map((pct) => (
                    <button key={pct} onClick={() => balance && setAmount((parseFloat(formatEther(balance)) * parseInt(pct) / 100).toFixed(4))}
                      className="px-3 py-1 text-xs font-medium text-blue-600 bg-blue-50 rounded-md hover:bg-blue-100">
                      {pct}%
                    </button>
                  ))}
                </div>
              </div>

              {/* Arrow */}
              <div className="flex justify-center py-2">
                <div className={`w-10 h-10 ${darkMode ? 'bg-slate-700' : 'bg-slate-100'} rounded-full flex items-center justify-center border-4 ${darkMode ? 'border-slate-800' : 'border-white'} shadow-sm`}>
                  <svg className={`w-5 h-5 ${subTextClass}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 14l-7 7m0 0l-7-7m7 7V3" />
                  </svg>
                </div>
              </div>

              {/* To */}
              <div className={`${inputBgClass} rounded-xl p-4 mb-4 border`}>
                <div className="flex justify-between text-sm mb-2">
                  <span className={subTextClass}>To {destChain}</span>
                  <span className={subTextClass}>You receive</span>
                </div>
                <div className="flex items-center gap-3">
                  <span className={`flex-1 text-2xl font-medium ${textClass}`}>{amount || '0.00'}</span>
                  <div className={`${cardClass} border rounded-lg px-3 py-2`}>
                    <span className={`${textClass} font-medium text-sm`}>{direction === 'forward' ? 'wTEST' : 'TEST'}</span>
                  </div>
                </div>
              </div>

              {/* Custom Recipient */}
              <div className="mb-6">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input type="checkbox" checked={useCustomRecipient} onChange={(e) => setUseCustomRecipient(e.target.checked)}
                    className="w-4 h-4 rounded border-slate-300" />
                  <span className={`text-sm ${subTextClass}`}>Send to different address</span>
                </label>
                {useCustomRecipient && (
                  <input type="text" placeholder="0x..." value={recipient} onChange={(e) => setRecipient(e.target.value)}
                    className={`mt-2 w-full px-3 py-2 rounded-lg ${inputBgClass} border ${textClass} text-sm font-mono outline-none`} />
                )}
              </div>

              {/* Button */}
              {!isConnected ? (
                <ConnectButton.Custom>
                  {({ openConnectModal }) => (
                    <button onClick={openConnectModal}
                      className="w-full py-4 bg-blue-600 text-white font-medium rounded-xl hover:bg-blue-700 transition-colors">
                      Connect Wallet
                    </button>
                  )}
                </ConnectButton.Custom>
              ) : isWrongNetwork ? (
                <button onClick={handleSwitchNetwork}
                  className="w-full py-4 bg-amber-500 text-white font-medium rounded-xl hover:bg-amber-600">
                  Switch to {sourceChain}
                </button>
              ) : (
                <button onClick={showConfirmation} disabled={!amount || parseFloat(amount) <= 0}
                  className="w-full py-4 bg-blue-600 text-white font-medium rounded-xl hover:bg-blue-700 disabled:bg-slate-300 disabled:cursor-not-allowed transition-all">
                  Bridge Tokens
                </button>
              )}
            </>
          )}
        </div>

        {/* FAQ Section */}
        <div className="mt-6">
          <button onClick={() => setShowFaq(!showFaq)}
            className={`w-full flex justify-between items-center p-4 ${cardClass} rounded-xl border`}>
            <span className={`font-medium ${textClass}`}>How does it work?</span>
            <svg className={`w-5 h-5 ${subTextClass} transition-transform ${showFaq ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
            </svg>
          </button>
          {showFaq && (
            <div className={`mt-2 p-4 ${cardClass} rounded-xl border space-y-4`}>
              <div>
                <h4 className={`font-medium ${textClass} mb-1`}>What is ChainBridge?</h4>
                <p className={`text-sm ${subTextClass}`}>ChainBridge allows you to transfer tokens between Sepolia and Hoodi testnets securely.</p>
              </div>
              <div>
                <h4 className={`font-medium ${textClass} mb-1`}>How long does it take?</h4>
                <p className={`text-sm ${subTextClass}`}>Typically 1-2 minutes. The relayer monitors your transaction and completes the bridge automatically.</p>
              </div>
              <div>
                <h4 className={`font-medium ${textClass} mb-1`}>Is it safe?</h4>
                <p className={`text-sm ${subTextClass}`}>This is a testnet demo. Smart contracts are verified but not audited. Use only with test tokens.</p>
              </div>
            </div>
          )}
        </div>

        {/* Contract Info */}
        <div className={`mt-4 p-4 ${cardClass} rounded-xl border`}>
          <p className={`text-xs ${subTextClass} mb-2`}>Contract Addresses</p>
          <div className="space-y-1">
            <div className="flex justify-between text-xs">
              <span className={subTextClass}>Vault</span>
              <a href={`https://sepolia.etherscan.io/address/${CONTRACTS.sepolia.vault}`} target="_blank" className="text-blue-600 font-mono">
                {CONTRACTS.sepolia.vault.slice(0, 6)}...{CONTRACTS.sepolia.vault.slice(-4)}
              </a>
            </div>
          </div>
        </div>

        <p className={`text-center mt-4 text-xs ${subTextClass}`}>Testnet Demo - Not Audited</p>
      </main>
    </div>
  );
}
