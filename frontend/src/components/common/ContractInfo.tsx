// ============================================
// Contract info - Display deployed addresses
// ============================================

import { useTheme } from '../../hooks';
import { CONTRACTS } from '../../constants';

const LINKS = [
  { label: 'Vault (Sepolia)', address: CONTRACTS.sepolia.vault, explorer: 'https://sepolia.etherscan.io' },
  { label: 'Router (Sepolia)', address: CONTRACTS.sepolia.router, explorer: 'https://sepolia.etherscan.io' },
  { label: 'TEST Token', address: CONTRACTS.sepolia.testToken, explorer: 'https://sepolia.etherscan.io' },
  { label: 'Router (Hoodi)', address: CONTRACTS.hoodi.router, explorer: 'https://explorer.hoodi.ethpandaops.io' },
  { label: 'wTEST Token', address: CONTRACTS.hoodi.wrappedToken, explorer: 'https://explorer.hoodi.ethpandaops.io' },
];

export function ContractInfo() {
  const { cardClass, subTextClass } = useTheme();

  return (
    <div className={`mt-4 p-4 ${cardClass} rounded-xl border`}>
      <p className={`text-xs font-semibold ${subTextClass} uppercase tracking-wider mb-3`}>
        Contract Addresses
      </p>
      <div className="space-y-2">
        {LINKS.map(({ label, address, explorer }) => (
          <div key={label} className="flex justify-between items-center text-xs">
            <span className={subTextClass}>{label}</span>
            <a
              href={`${explorer}/address/${address}`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-blue-500 hover:text-blue-400 font-mono transition-colors"
            >
              {address.slice(0, 6)}...{address.slice(-4)}
            </a>
          </div>
        ))}
      </div>
    </div>
  );
}
