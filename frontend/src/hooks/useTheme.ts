// ============================================
// Theme hook - Dark/Light mode management
// ============================================

import { useState, useEffect, useCallback, createContext, useContext } from 'react';
import type { ThemeContextType } from '../types';

const STORAGE_KEY = 'chainbridge-theme';

const ThemeContext = createContext<ThemeContextType | null>(null);

export function useThemeProvider() {
  const [darkMode, setDarkMode] = useState(false);

  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) setDarkMode(saved === 'dark');
  }, []);

  const toggleDarkMode = useCallback(() => {
    setDarkMode(prev => {
      const next = !prev;
      localStorage.setItem(STORAGE_KEY, next ? 'dark' : 'light');
      return next;
    });
  }, []);

  const theme: ThemeContextType = {
    darkMode,
    toggleDarkMode,
    bgClass: darkMode ? 'bg-slate-950' : 'bg-gradient-to-br from-slate-50 to-blue-50',
    cardClass: darkMode ? 'bg-slate-900 border-slate-800' : 'bg-white border-slate-200',
    textClass: darkMode ? 'text-white' : 'text-slate-900',
    subTextClass: darkMode ? 'text-slate-400' : 'text-slate-500',
    inputBgClass: darkMode ? 'bg-slate-800 border-slate-700' : 'bg-slate-50 border-slate-200',
  };

  return theme;
}

export { ThemeContext };

export function useTheme(): ThemeContextType {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used inside ThemeProvider');
  return ctx;
}
