// ============================================
// Direction toggle - Switch between Sepolia<>Hoodi
// ============================================

import { useTheme } from '../../hooks';
import type { Direction } from '../../types';

interface Props {
  direction: Direction;
  onChange: (dir: Direction) => void;
}

export function DirectionToggle({ direction, onChange }: Props) {
  const { darkMode, cardClass, textClass, subTextClass } = useTheme();

  return (
    <div className={`flex ${darkMode ? 'bg-slate-800' : 'bg-slate-100'} rounded-xl p-1 mb-6`}>
      <button
        onClick={() => onChange('forward')}
        className={`flex-1 py-2.5 text-sm font-medium rounded-lg transition-all duration-200 ${
          direction === 'forward'
            ? `${cardClass} shadow-sm ${textClass}`
            : `${subTextClass} hover:text-slate-600`
        }`}
      >
        Sepolia to Hoodi
      </button>
      <button
        onClick={() => onChange('reverse')}
        className={`flex-1 py-2.5 text-sm font-medium rounded-lg transition-all duration-200 ${
          direction === 'reverse'
            ? `${cardClass} shadow-sm ${textClass}`
            : `${subTextClass} hover:text-slate-600`
        }`}
      >
        Hoodi to Sepolia
      </button>
    </div>
  );
}
