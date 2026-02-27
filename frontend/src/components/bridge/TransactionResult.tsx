// ============================================
// Transaction result - Success/Error states
// ============================================

import { useTheme } from '../../hooks';

interface SuccessProps {
  type: 'success';
  destChain: string;
  txHash: string;
  explorerUrl: string;
  onReset: () => void;
}

interface ErrorProps {
  type: 'error';
  message: string;
  onReset: () => void;
}

type Props = SuccessProps | ErrorProps;

export function TransactionResult(props: Props) {
  const { darkMode, textClass, subTextClass } = useTheme();

  if (props.type === 'success') {
    return (
      <div className="text-center py-8">
        {/* Success icon */}
        <div className="relative mx-auto mb-5 w-16 h-16">
          <div className="absolute inset-0 bg-green-500/20 rounded-full animate-ping" />
          <div className="relative w-16 h-16 bg-gradient-to-br from-green-400 to-green-600 rounded-full flex items-center justify-center shadow-lg shadow-green-500/30">
            <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
            </svg>
          </div>
        </div>

        <h3 className={`text-xl font-bold ${textClass} mb-1`}>Bridge Successful</h3>
        <p className={`${subTextClass} mb-5 text-sm`}>Tokens arriving on {props.destChain}</p>

        {props.txHash && (
          <a
            href={props.explorerUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 text-blue-500 hover:text-blue-400 text-sm font-medium mb-6 transition-colors"
          >
            View on Explorer
            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
            </svg>
          </a>
        )}

        <button
          onClick={props.onReset}
          className={`w-full py-3.5 font-medium rounded-xl transition-all ${
            darkMode ? 'bg-slate-800 text-white hover:bg-slate-700' : 'bg-slate-100 text-slate-900 hover:bg-slate-200'
          }`}
        >
          Bridge More
        </button>
      </div>
    );
  }

  return (
    <div className="text-center py-8">
      {/* Error icon */}
      <div className="w-16 h-16 bg-gradient-to-br from-red-400 to-red-600 rounded-full flex items-center justify-center mx-auto mb-5 shadow-lg shadow-red-500/30">
        <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M6 18L18 6M6 6l12 12" />
        </svg>
      </div>

      <h3 className={`text-xl font-bold ${textClass} mb-1`}>Transaction Failed</h3>
      <p className={`${subTextClass} mb-6 text-sm`}>{props.message}</p>

      <button
        onClick={props.onReset}
        className="w-full py-3.5 bg-blue-600 text-white font-medium rounded-xl hover:bg-blue-700 transition-all shadow-lg shadow-blue-600/20"
      >
        Try Again
      </button>
    </div>
  );
}
