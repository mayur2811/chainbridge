// ============================================
// FAQ section - Expandable Q&A
// ============================================

import { useState } from 'react';
import { useTheme } from '../../hooks';

const FAQ_ITEMS = [
  {
    question: 'What is ChainBridge?',
    answer: 'ChainBridge allows you to transfer tokens between Sepolia and Hoodi testnets securely using a lock-and-mint mechanism.',
  },
  {
    question: 'How long does it take?',
    answer: 'Typically 1-2 minutes. The relayer monitors your transaction and completes the bridge automatically.',
  },
  {
    question: 'Is it safe?',
    answer: 'This is a testnet demo. Smart contracts use OpenZeppelin security standards but are not professionally audited. Use only with test tokens.',
  },
  {
    question: 'How do I get TEST tokens?',
    answer: 'You can mint TEST tokens from the faucet or receive them from the deployer address on Sepolia testnet.',
  },
];

export function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(null);
  const { darkMode, cardClass, textClass, subTextClass } = useTheme();

  return (
    <div className="mt-6 space-y-2">
      <h3 className={`text-sm font-semibold ${subTextClass} uppercase tracking-wider mb-3 px-1`}>
        Frequently Asked
      </h3>
      {FAQ_ITEMS.map((item, i) => (
        <div key={i} className={`${cardClass} rounded-xl border overflow-hidden transition-all duration-200`}>
          <button
            onClick={() => setOpenIndex(openIndex === i ? null : i)}
            className="w-full flex justify-between items-center p-4 text-left"
          >
            <span className={`font-medium text-sm ${textClass}`}>{item.question}</span>
            <svg
              className={`w-4 h-4 ${subTextClass} transition-transform duration-200 flex-shrink-0 ml-2 ${
                openIndex === i ? 'rotate-180' : ''
              }`}
              fill="none" stroke="currentColor" viewBox="0 0 24 24"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
            </svg>
          </button>
          <div className={`overflow-hidden transition-all duration-200 ${openIndex === i ? 'max-h-40' : 'max-h-0'}`}>
            <p className={`px-4 pb-4 text-sm ${subTextClass} leading-relaxed ${
              darkMode ? 'border-t border-slate-800' : 'border-t border-slate-100'
            } pt-3`}>
              {item.answer}
            </p>
          </div>
        </div>
      ))}
    </div>
  );
}
