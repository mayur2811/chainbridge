// ============================================
// Network warning - Shows when user needs to switch
// ============================================

import { useTheme } from '../../hooks';

interface Props {
  chainName: string;
  onSwitch: () => void;
}

export function NetworkWarning({ chainName, onSwitch }: Props) {
  const { darkMode } = useTheme();

  return (
    <div className={`rounded-xl p-3.5 mb-4 border ${
      darkMode
        ? 'bg-amber-500/10 border-amber-500/20'
        : 'bg-amber-50 border-amber-200'
    }`}>
      <div className="flex items-center gap-2 mb-2">
        <svg className="w-4 h-4 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
        </svg>
        <p className={`text-sm font-medium ${darkMode ? 'text-amber-400' : 'text-amber-800'}`}>
          Wrong network detected
        </p>
      </div>
      <button
        onClick={onSwitch}
        className={`w-full py-2.5 text-sm font-medium rounded-lg transition-all ${
          darkMode
            ? 'bg-amber-500/20 text-amber-400 hover:bg-amber-500/30'
            : 'bg-amber-100 text-amber-800 hover:bg-amber-200'
        }`}
      >
        Switch to {chainName}
      </button>
    </div>
  );
}
