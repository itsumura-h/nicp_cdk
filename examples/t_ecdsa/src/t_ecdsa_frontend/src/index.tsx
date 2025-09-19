import { hydrate, prerender as ssr } from 'preact-iso';
import { useState, useEffect } from 'preact/hooks';
import {
	type LocalAccount,
	Address,
	verifyMessage,
	http,
} from 'viem';
import { anvil } from 'viem/chains';
import { useIcpAuth } from './hooks/icpAuth';
import { createIcpWalletClient, type IcpWalletClient } from './hooks/icpWalletClient';
import { useCounterContract } from './hooks/useCounterContract';
import { publicClient } from './hooks/client';
import counterAbi from '../../../../../solidity/out/Counter.sol/Counter.json';

export function App() {
	const { authClient, isAuthenticated, isLoading, principal, login, logout } = useIcpAuth();
	const [walletClient, setWalletClient] = useState<IcpWalletClient | null>(null);
	const [accountAddress, setAccountAddress] = useState<Address | null>(null);
	const [message, setMessage] = useState<string>('hello world');
	const [signature, setSignature] = useState<string | null>(null);
	const [isValid, setIsValid] = useState<boolean | null>(null);
	const [counterValue, setCounterValue] = useState<bigint | null>(null);
	
	// カスタムフックでcounterContractを管理
	const { counterContract, contractAddress } = useCounterContract();

	useEffect(() => {
		if (!authClient || !isAuthenticated) {
			setWalletClient(null);
			setAccountAddress(null);
			return;
		}

		let cancelled = false;

		(async () => {
		try {
			// ICPキャニスター経由で署名を行うLocalAccountを直接作成
			const walletClient = await createIcpWalletClient({
				authClient,
				chain: anvil,
				transport: http('http://localhost:8545'),
			});
			setWalletClient(walletClient);
			if (cancelled) {
				return;
			}
			setAccountAddress(walletClient.account.address);
			console.log('ICP Account created successfully:', walletClient.account.address);
			} catch (error) {
				if (!cancelled) {
					console.error('Failed to create ICP account:', error);
					setWalletClient(null);
					setAccountAddress(null);
				}
			}
		})();

		return () => {
			cancelled = true;
		};
	}, [authClient, isAuthenticated]);

	const handleAuth = async () => {
		if (isAuthenticated) {
			await logout();
			setWalletClient(null);
			setAccountAddress(null);
			setSignature(null);
			setIsValid(null);
			return;
		}

		await login();
	};

	const handleSign = async () => {
		if (!walletClient || !accountAddress) {
			return;
		}

		try {
			// LocalAccountのsignMessage関数を直接呼び出し（RPC不要）
			const signed = await walletClient.signMessage({
				account: walletClient.account,
				message,
			});
			setSignature(signed);
			// クライアント側で署名検証
			const verified = await verifyMessage({
				address: accountAddress,
				message,
				signature: signed,
			});
			setIsValid(verified);
		} catch (error) {
			console.error('Failed to sign message:', error);
			setSignature(null);
			setIsValid(null);
		}
	};

	const readCounterValue = async () => {
		try {
			const value = await publicClient.readContract({
				address: contractAddress,
				abi: counterAbi.abi,
				functionName: 'number',
			});
			setCounterValue(value as bigint);
		} catch (error) {
			console.error('Failed to read counter value:', error);
			setCounterValue(null);
		}
	};

	const handleIncrement = async () => {
		if (!walletClient || !contractAddress) {
			return;
		}
		try {
			await walletClient.writeContract({
				address: contractAddress as Address,
				chain: anvil,
				account: walletClient.account,
				abi: counterAbi.abi,
				functionName: 'increment',
			});
			// インクリメント後にカウンター値を再読み込み
			await readCounterValue();
		} catch (error) {
			console.error('Failed to increment counter:', error);
		}
	};

	return (
		<main>
			<article>
				<h2>T-ECDSA</h2>
				<button onClick={handleAuth} disabled={isLoading || !authClient}>
					{isAuthenticated ? 'Logout' : 'Login with Internet Identity'}
				</button>
				<p>Status: {isLoading ? 'Checking…' : isAuthenticated ? 'Authenticated' : 'Not authenticated'}</p>
				{isAuthenticated && (
					<>
						<p>Principal: {principal}</p>
						<p>Account Address: {accountAddress}</p>
						<p>Counter Contract: {contractAddress}</p>
						<p>Contract Ready: {counterContract ? 'Yes' : 'No'}</p>
					</>
				)}
				<hr />
				<input
					type="text"
					placeholder="Message"
					onInput={(e) => setMessage((e.target as HTMLInputElement).value)}
					value={message}
				/>
				<button onClick={handleSign} disabled={!walletClient || !accountAddress}>
					Sign
				</button>
				<p>Signature: {signature}</p>
				<p>isValid: {isValid !== null ? isValid.toString() : 'Not verified yet'}</p>
				<hr />
				<button onClick={readCounterValue} disabled={!contractAddress}>
					Read Counter
				</button>
				<button onClick={handleIncrement} disabled={!walletClient || !contractAddress}>
					Increment
				</button>
				<p>Counter: {counterValue !== null ? counterValue.toString() : 'Not read yet'}</p>
			</article>
		</main>
	);
}

if (typeof window !== 'undefined') {
	hydrate(<App />, document.getElementById('app'));
}

export async function prerender(data) {
	return await ssr(<App {...data} />);
}
