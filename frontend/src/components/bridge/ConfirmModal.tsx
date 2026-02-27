// ============================================
// Confirm modal - Review before submitting
// ============================================

import { useTheme } from '../../hooks';

interface Props {
  amount: string;
  symbol: string;
  sourceChain: string;
  destChain: string;
  recipient: string;
  useCustomRecipient: boolean;
  customRecipient: string;
  onConfirm: () => void;
  onCancel: () => void;
}

export function ConfirmModal({
  amount, symbol, sourceChain, destChain,
  useCustomRecipient, customRecipient,
  onConfirm, onCancel,
}: Props) {
  const { darkMode, textClass, subTextClass, inputBgClass } = useTheme();

  const displayRecipient = useCustomRecipient && customRecipient
    ? `${customRecipient.slice(0, 6)}...${customRecipient.slice(-4)}`
    : 'Your wallet';

  return (
    <div className="py-6">
      <div className="flex items-center justify-center mb-4">
        <div className={`w-12 h-12 rounded-full flex items-center justify-center ${
          darkMode ? 'bg-blue-500/20' : 'bg-blue-50'
        }`}>
          <svg className="w-6 h-6 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
      </div>
      <h3 className={`text-lg font-bold ${textClass} text-center mb-5`}>Confirm Bridge</h3>

      <div className={`${inputBgClass} rounded-xl p-4 mb-5 border space-y-3`}>
        <Row label="Amount" value={`${amount} ${symbol}`} textClass={textClass} subTextClass={subTextClass} bold />
        <Row label="From" value={sourceChain} textClass={textClass} subTextClass={subTextClass} />
        <Row label="To" value={destChain} textClass={textClass} subTextClass={subTextClass} />
        <Row label="Recipient" value={displayRecipient} textClass={textClass} subTextClass={subTextClass} mono />
      </div>

      <div className="flex gap-3">
        <button
          onClick={onCancel}
          className={`flex-1 py-3 rounded-xl font-medium transition-all ${
            darkMode ? 'bg-slate-800 text-white hover:bg-slate-700' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
          }`}
        >
          Cancel
        </button>
        <button
          onClick={onConfirm}
          className="flex-1 py-3 bg-blue-600 text-white font-medium rounded-xl hover:bg-blue-700 transition-all shadow-lg shadow-blue-600/20"
        >
          Confirm Bridge
        </button>
      </div>
    </div>
  );
}

function Row({ label, value, textClass, subTextClass, bold, mono }: {
  label: string; value: string; textClass: string; subTextClass: string; bold?: boolean; mono?: boolean;
}) {
  return (
    <div className="flex justify-between items-center">
      <span className={`text-sm ${subTextClass}`}>{label}</span>
      <span className={`text-sm ${textClass} ${bold ? 'font-semibold' : ''} ${mono ? 'font-mono' : ''}`}>{value}</span>
    </div>
  );
}
