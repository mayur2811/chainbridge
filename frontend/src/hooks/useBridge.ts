// ============================================
// Bridge hook - All bridge transaction logic
// ============================================

import { useState, useCallback, useMemo } from 'react';
import { useAccount, useChainId, useSwitchChain, useWriteContract, useReadContract } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { CONTRACTS, VAULT_ABI, TOKEN_ABI, WRAPPED_TOKEN_ABI, hoodi, sepolia, CHAIN_CONFIG } from '../constants';
import type { Step, Direction } from '../types';

export function useBridge() {
  const [amount, setAmount] = useState('');
  const [recipient, setRecipient] = useState('');
  const [useCustomRecipient, setUseCustomRecipient] = useState(false);
  const [direction, setDirection] = useState<Direction>('forward');
  const [step, setStep] = useState<Step>('idle');
  const [txHash, setTxHash] = useState('');
  const [errorMsg, setErrorMsg] = useState('');

  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();
  const { writeContractAsync } = useWriteContract();

  // Derived values
  const chainConfig = CHAIN_CONFIG[direction];
  const requiredChainId = chainConfig.source.chainId;
  const isWrongNetwork = isConnected && chainId !== requiredChainId;

  // Balance reads
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

  const balance = direction === 'forward' ? testBalance : wrappedBalance;
  const isLoadingBalance = direction === 'forward' ? testLoading : wrappedLoading;
  const formattedBalance = balance ? parseFloat(formatEther(balance)).toFixed(4) : '0.00';

  const explorerUrl = useMemo(() => {
    if (!txHash) return '';
    return `${chainConfig.source.explorer}/tx/${txHash}`;
  }, [txHash, chainConfig]);

  // Actions
  const showConfirmation = useCallback(() => {
    if (!amount || parseFloat(amount) <= 0) return;
    setStep('confirming');
  }, [amount]);

  const handleBridge = useCallback(async () => {
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
  }, [amount, address, direction, useCustomRecipient, recipient, writeContractAsync]);

  const handleSwitchNetwork = useCallback(() => {
    switchChain({ chainId: requiredChainId });
  }, [switchChain, requiredChainId]);

  const resetState = useCallback(() => {
    setStep('idle');
    setTxHash('');
    setErrorMsg('');
    setAmount('');
  }, []);

  const setPercentage = useCallback((pct: number) => {
    if (balance) {
      setAmount((parseFloat(formatEther(balance)) * pct / 100).toFixed(4));
    }
  }, [balance]);

  return {
    // State
    amount, setAmount,
    recipient, setRecipient,
    useCustomRecipient, setUseCustomRecipient,
    direction, setDirection,
    step, txHash, errorMsg,

    // Derived
    chainConfig,
    isConnected,
    isWrongNetwork,
    balance,
    formattedBalance,
    isLoadingBalance,
    explorerUrl,

    // Actions
    showConfirmation,
    handleBridge,
    handleSwitchNetwork,
    resetState,
    setPercentage,
  };
}
