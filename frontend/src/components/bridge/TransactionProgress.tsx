// ============================================
// Transaction progress - Step indicator during bridge
// ============================================

import { useTheme } from '../../hooks';
import type { Step } from '../../types';

interface Props {
  step: Step;
  txHash: string;
  explorerUrl: string;
}

const STEPS = ['Approve', 'Bridge', 'Confirm'] as const;

export function TransactionProgress({ step, txHash, explorerUrl }: Props) {
  const { darkMode, subTextClass } = useTheme();

  const stepIndex = step === 'approving' ? 0 : step === 'bridging' ? 1 : 2;

  return (
    <div className="py-8">
      {/* Step indicators */}
      <div className="flex justify-between mb-8 px-4">
        {STEPS.map((label, i) => {
          const isActive = i === stepIndex;
          const isComplete = i < stepIndex;

          return (
            <div key={label} className="flex flex-col items-center flex-1">
              {/* Circle */}
              <div className={`w-11 h-11 rounded-full flex items-center justify-center mb-2 transition-all duration-500 ${
                isComplete
                  ? 'bg-green-500 shadow-lg shadow-green-500/30'
                  : isActive
                    ? 'bg-blue-600 shadow-lg shadow-blue-600/30'
                    : darkMode ? 'bg-slate-800' : 'bg-slate-200'
              }`}>
                {isComplete ? (
                  <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
                  </svg>
                ) : isActive ? (
                  <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                ) : (
                  <span className={`text-sm font-medium ${subTextClass}`}>{i + 1}</span>
                )}
              </div>

              {/* Label */}
              <span className={`text-xs font-medium ${
                isActive ? 'text-blue-500' : isComplete ? 'text-green-500' : subTextClass
              }`}>
                {label}
              </span>

              {/* Connector line */}
              {i < STEPS.length - 1 && (
                <div className={`absolute h-0.5 w-1/4 top-5 ${
                  isComplete ? 'bg-green-500' : darkMode ? 'bg-slate-800' : 'bg-slate-200'
                }`} />
              )}
            </div>
          );
        })}
      </div>

      {/* Status text */}
      <div className="text-center">
        <p className={`${subTextClass} text-sm`}>
          {step === 'approving' && 'Waiting for token approval...'}
          {step === 'bridging' && 'Locking tokens in vault...'}
          {step === 'waiting' && 'Confirming on destination chain...'}
        </p>
        <p className={`text-xs ${subTextClass} mt-1 opacity-60`}>
          Please confirm in your wallet
        </p>
      </div>

      {/* TX Link */}
      {txHash && (
        <div className="mt-5 text-center">
          <a
            href={explorerUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 text-blue-500 hover:text-blue-400 text-sm font-medium transition-colors"
          >
            View on Explorer
            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
            </svg>
          </a>
        </div>
      )}
    </div>
  );
}
