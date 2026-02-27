// ============================================
// Token input - From/To panels with balance display
// ============================================

import { useTheme } from '../../hooks';

interface Props {
  label: string;
  chainName: string;
  symbol: string;
  amount: string;
  balance?: string;
  isLoading?: boolean;
  readOnly?: boolean;
  onAmountChange?: (val: string) => void;
  onPercentage?: (pct: number) => void;
}

export function TokenInput({
  label,
  chainName,
  symbol,
  amount,
  balance,
  isLoading,
  readOnly = false,
  onAmountChange,
  onPercentage,
}: Props) {
  const { darkMode, cardClass, textClass, subTextClass, inputBgClass } = useTheme();

  return (
    <div className={`${inputBgClass} rounded-xl p-4 border transition-all duration-200 ${
      !readOnly ? 'focus-within:border-blue-500/50 focus-within:ring-1 focus-within:ring-blue-500/20' : ''
    }`}>
      <div className="flex justify-between text-sm mb-2">
        <span className={subTextClass}>{label} {chainName}</span>
        {balance !== undefined && (
          <span className={subTextClass}>
            Balance:{' '}
            {isLoading ? (
              <span className={`inline-block w-16 h-4 ${darkMode ? 'bg-slate-700' : 'bg-slate-300'} rounded animate-pulse align-middle`} />
            ) : (
              <span className={`font-medium ${textClass}`}>{balance}</span>
            )}
          </span>
        )}
        {readOnly && <span className={subTextClass}>You receive</span>}
      </div>

      <div className="flex items-center gap-3">
        {readOnly ? (
          <span className={`flex-1 text-2xl font-semibold ${textClass}`}>{amount || '0.00'}</span>
        ) : (
          <input
            type="number"
            placeholder="0.00"
            value={amount}
            onChange={(e) => onAmountChange?.(e.target.value)}
            className={`flex-1 text-2xl font-semibold ${textClass} bg-transparent outline-none placeholder-slate-400`}
          />
        )}
        <div className={`${cardClass} border rounded-lg px-3 py-2`}>
          <span className={`${textClass} font-semibold text-sm`}>{symbol}</span>
        </div>
      </div>

      {/* Percentage buttons */}
      {!readOnly && onPercentage && (
        <div className="flex gap-2 mt-3">
          {[25, 50, 75, 100].map((pct) => (
            <button
              key={pct}
              onClick={() => onPercentage(pct)}
              className={`px-3 py-1 text-xs font-medium rounded-md transition-all ${
                darkMode
                  ? 'text-blue-400 bg-blue-500/10 hover:bg-blue-500/20'
                  : 'text-blue-600 bg-blue-50 hover:bg-blue-100'
              }`}
            >
              {pct}%
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
