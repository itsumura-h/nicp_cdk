import { hydrate, prerender as ssr } from 'preact-iso';
import { useState, useEffect } from 'preact/hooks';
import { Address, verifyMessage, http } from 'viem';
import { anvil } from 'viem/chains';
import { WagmiProvider } from 'wagmi';
import { QueryClientProvider } from '@tanstack/react-query';
import { useIcpAuth } from './hooks/icpAuth';
import { createIcpWalletClient, type IcpWalletClient } from './hooks/icpWalletClient';
import { useCounterContract } from './hooks/useCounterContract';
import { useWagmiWallet } from './hooks/useWagmiWallet';
import { wagmiConfig } from './hooks/wagmiConfig';
import { queryClient } from './hooks/queryClient';

// window.ethereumの型定義
declare global {
  interface Window {
    ethereum?: any;
    icpEthereum?: any;
    originalEthereum?: any;
  }
}

// Wagmi統合デモコンポーネント
function WagmiDemo() {
	const {
		// Wagmi関連
		wagmiAddress,
		isWagmiConnected,
		isWagmiConnecting,
		wagmiWalletClient,
		connectWagmi,
		disconnectWagmi,
		
		// ICP認証関連
		icpAddress,
		isIcpAuthenticated,
		icpWalletClient,
		loginIcp,
		logoutIcp,
	} = useWagmiWallet();

	// カスタムwalletClientの状態管理
	const [customWalletClient, setCustomWalletClient] = useState<IcpWalletClient | null>(null);
	const [accountAddress, setAccountAddress] = useState<Address | null>(null);
	const [counterValue, setCounterValue] = useState<bigint | null>(null);
	const [number, setNumber] = useState<bigint | null>(null);
	const [testMessage, setTestMessage] = useState<string>('Hello from ICP!');
	const [signature, setSignature] = useState<string | null>(null);

	// カスタムフックでcounterContractを管理
	const { contract: counterContract, contractAddress } = useCounterContract(customWalletClient);

	// ICP認証成功時にカスタムwalletClientを作成
	useEffect(() => {
		if (!isIcpAuthenticated) {
			setCustomWalletClient(null);
			setAccountAddress(null);
			return;
		}

		// icpWalletClientがすでに存在する場合はそれを使用
		if (icpWalletClient) {
			setCustomWalletClient(icpWalletClient);
			setAccountAddress(icpWalletClient.account.address);
			console.log('Using existing ICP Wallet Client with window.ethereum:', icpWalletClient.account.address);
		}
	}, [isIcpAuthenticated, icpWalletClient]);

	const readCounterValue = async () => {
		if (!counterContract) {
			return;
		}
		try {
			const value = await counterContract.read.number();
			setCounterValue(value as bigint);
		} catch (error) {
			console.error('Failed to read counter value:', error);
			setCounterValue(null);
		}
	};

	const handleIncrement = async () => {
		if (!customWalletClient || !counterContract) {
			return;
		}
		try {
			const hash = await counterContract.write.increment();
			console.log('Transaction hash:', hash);
			await readCounterValue();
		} catch (error) {
			console.error('Failed to increment counter:', error);
		}
	};

	const handleSetNumber = async () => {
		if (!customWalletClient || !counterContract || number === null) {
			return;
		}
		try {
			const hash = await counterContract.write.setNumber([number]);
			console.log('Transaction hash:', hash);
			await readCounterValue();
		} catch (error) {
			console.error('Failed to set number:', error);
		}
	};

	const handleNumberInput = (e: Event) => {
		const target = e.target as HTMLInputElement;
		const value = target.value.trim();
		
		if (value === '') {
			setNumber(null);
			return;
		}
		
		try {
			setNumber(BigInt(value));
		} catch (error) {
			console.error('Invalid number input:', error);
		}
	};

	// window.ethereum経由でICP署名をテスト
	const testIcpSigning = async () => {
		if (typeof window === 'undefined') {
			console.error('Window not available');
			return;
		}

		// ICPプロバイダーを確実に取得
		const icpProvider = (window as any).icpEthereum;
		
		if (!icpProvider) {
			console.error('ICP Ethereum provider not available. Make sure you are authenticated with Internet Identity.');
			return;
		}

		// プロバイダーがICPのものかチェック
		if (!icpProvider.isIcpProvider) {
			console.error('Provider is not ICP provider:', icpProvider);
			return;
		}

		try {
			console.log('Using ICP provider:', icpProvider);
			console.log('Provider type:', icpProvider.constructor.name);
			
			// ICPプロバイダーのpersonal_signを呼び出し
			const accounts = await icpProvider.request({ method: 'eth_requestAccounts' }) as string[];
			if (accounts.length === 0) {
				throw new Error('No accounts available');
			}

			console.log('ICP accounts:', accounts);

			const signature = await icpProvider.request({
				method: 'personal_sign',
				params: [testMessage, accounts[0]]
			}) as string;

			setSignature(signature);
			console.log('ICP Signature via ICP provider:', signature);
		} catch (error) {
			console.error('Failed to sign with ICP via ICP provider:', error);
			setSignature(null);
		}
	};

	return (
		<div>
			<h3>Wagmi Integration Demo</h3>
			<div>
				<h4>ICP Authentication</h4>
				<button onClick={loginIcp} disabled={isIcpAuthenticated}>
					{isIcpAuthenticated ? 'ICP Authenticated' : 'Login with Internet Identity'}
				</button>
				{isIcpAuthenticated && (
					<>
						<p>ICP Address: {icpAddress}</p>
						<button onClick={logoutIcp}>Logout ICP</button>
					</>
				)}
			</div>
			
			<div>
				<h4>Wagmi Connection</h4>
				<button 
					onClick={connectWagmi} 
					disabled={isWagmiConnected || isWagmiConnecting || !isIcpAuthenticated}
				>
					{isWagmiConnecting ? 'Connecting...' : isWagmiConnected ? 'Wagmi Connected' : 'Connect Wagmi'}
				</button>
				{isWagmiConnected && (
					<>
						<p>Wagmi Address: {wagmiAddress}</p>
						<p>Address Match: {wagmiAddress === icpAddress ? '✅' : '❌'}</p>
						<button onClick={disconnectWagmi}>Disconnect Wagmi</button>
					</>
				)}
			</div>

			{/* カスタムWalletClient情報 */}
			<div>
				<h4>Custom Wallet Client (using window.ethereum)</h4>
				<p>Custom Wallet Address: {accountAddress}</p>
				<p>Counter Contract: {contractAddress}</p>
				<p>Contract Ready: {counterContract ? 'Yes' : 'No'}</p>
				<p>window.ethereum available: {typeof window !== 'undefined' && window.ethereum ? 'Yes' : 'No'}</p>
				<p>window.icpEthereum available: {typeof window !== 'undefined' && (window as any).icpEthereum ? 'Yes' : 'No'}</p>
				<p>Original ethereum backed up: {typeof window !== 'undefined' && (window as any).originalEthereum ? 'Yes' : 'No'}</p>
			</div>

			{/* ICP署名テスト */}
			{isIcpAuthenticated && (
				<div>
					<h4>ICP Signing Test (via window.ethereum)</h4>
					<input
						type="text"
						placeholder="Message to sign"
						onInput={(e) => setTestMessage((e.target as HTMLInputElement).value)}
						value={testMessage}
					/>
					<button onClick={testIcpSigning}>
						Sign with ICP via window.ethereum
					</button>
					<p>Signature: {signature || 'Not signed yet'}</p>
				</div>
			)}

			{/* コントラクト操作 */}
			{customWalletClient && (
				<div>
					<h4>Contract Operations</h4>
					<button onClick={readCounterValue}>
						Read Counter
					</button>
					<button onClick={handleIncrement} disabled={!counterContract}>
						+
					</button>
					<button onClick={handleSetNumber} disabled={!counterContract || number === null}>
						set
					</button>
					<input
						type="number"
						placeholder="Number"
						onInput={handleNumberInput}
						value={number?.toString() ?? ''}
					/>
					<p>Counter: {counterValue !== null ? counterValue.toString() : 'Not read yet'}</p>
				</div>
			)}
		</div>
	);
}

export function App() {
	const { authClient, isAuthenticated, isLoading, principal, login, logout } = useIcpAuth();
	const [message, setMessage] = useState<string>('hello world');
	const [signature, setSignature] = useState<string | null>(null);
	const [isValid, setIsValid] = useState<boolean | null>(null);


	const handleAuth = async () => {
		if (isAuthenticated) {
			await logout();
			setSignature(null);
			setIsValid(null);
			return;
		}

		await login();
	};

	// 署名機能は削除（WagmiDemoで実装）

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
					</>
				)}
				<hr />
				
				{/* Wagmi統合デモ */}
				<WagmiDemo />
				<hr />
				
				{/* 基本的な署名テスト */}
				<div>
					<h3>Basic Message Signing (Legacy)</h3>
					<input
						type="text"
						placeholder="Message"
						onInput={(e) => setMessage((e.target as HTMLInputElement).value)}
						value={message}
					/>
					<p>Note: Use Wagmi Demo above for wallet client operations</p>
					<p>Signature: {signature}</p>
					<p>isValid: {isValid !== null ? isValid.toString() : 'Not verified yet'}</p>
				</div>
			</article>
		</main>
	);
}

// プロバイダーでアプリをラップ
function AppWithProviders() {
	return (
		<QueryClientProvider client={queryClient}>
			<WagmiProvider config={wagmiConfig}>
				<App />
			</WagmiProvider>
		</QueryClientProvider>
	);
}

if (typeof window !== 'undefined') {
	hydrate(<AppWithProviders />, document.getElementById('app'));
}

export async function prerender(data) {
	return await ssr(<AppWithProviders {...data} />);
}
