import { useMemo } from 'preact/hooks';
import {
  type Address,
} from 'viem';
import { publicClient } from './client';
import { type IcpWalletClient } from './icpWalletClient';
import counterAbi from '../../../../../../solidity/out/Counter.sol/Counter.json';

const COUNTER_CONTRACT_ADDRESS: Address = '0x5FbDB2315678afecb367f032d93F642f64180aa3' as Address;

export const useCounterContract = (walletClient: IcpWalletClient | null) => {
  const contract = useMemo(() => {
    return {
      read: {
        number: async () => {
          return await publicClient.readContract({
            address: COUNTER_CONTRACT_ADDRESS,
            abi: counterAbi.abi,
            functionName: 'number',
          } as any);
        },
      },
      write: walletClient ? {
        increment: async () => {
          return await walletClient.writeContract({
            address: COUNTER_CONTRACT_ADDRESS,
            abi: counterAbi.abi,
            functionName: 'increment',
          } as any);
        },
        setNumber: async (args: [bigint]) => {
          return await walletClient.writeContract({
            address: COUNTER_CONTRACT_ADDRESS,
            abi: counterAbi.abi,
            functionName: 'setNumber',
            args,
          } as any);
        },
      } : {},
      address: COUNTER_CONTRACT_ADDRESS,
      abi: counterAbi.abi,
    };
  }, [walletClient]);

  return {
    contract,
    contractAddress: COUNTER_CONTRACT_ADDRESS,
  };
};
