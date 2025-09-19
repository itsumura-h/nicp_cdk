import { useMemo } from 'preact/hooks';
import { getContract, type Address } from 'viem';
import { publicClient } from './client';
import counterAbi from '../../../../../../solidity/out/Counter.sol/Counter.json';

const COUNTER_CONTRACT_ADDRESS: Address = '0x5FbDB2315678afecb367f032d93F642f64180aa3' as Address;

export function useCounterContract() {
	const counterContract = useMemo(() => {
		return getContract({
			address: COUNTER_CONTRACT_ADDRESS,
			abi: counterAbi.abi,
			client: publicClient,
		});
	}, []);

	return {
		counterContract,
		contractAddress: COUNTER_CONTRACT_ADDRESS,
	};
}
