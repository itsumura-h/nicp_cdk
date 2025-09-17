import { hydrate, prerender as ssr } from 'preact-iso';
import { useState, useEffect } from 'preact/hooks';
import { Address, createPublicClient, http } from 'viem';
import { mainnet } from 'viem/chains';
import { useIcpAuth } from './hooks/icpAuth';
import { createIcpWalletClient, type IcpWalletClient } from './hooks/icpWalletClient';

const transport = http();
const publicClient = createPublicClient({
	chain: mainnet,
	transport,
});

export function App() {
	const { authClient, isAuthenticated, isLoading, principal, login, logout } = useIcpAuth();
	const [walletClient, setWalletClient] = useState<IcpWalletClient | null>(null);
	const [accountAddress, setAccountAddress] = useState<Address | null>(null);
	const [message, setMessage] = useState<string>('hello world');
	const [signature, setSignature] = useState<string | null>(null);
	const [isValid, setIsValid] = useState<boolean | null>(null);

	useEffect(() => {
		if (!authClient || !isAuthenticated) {
			setWalletClient(null);
			setAccountAddress(null);
			return;
		}

		let cancelled = false;

		(async () => {
			try {
				const client = await createIcpWalletClient({
					authClient,
					chain: mainnet,
					transport,
				});
				if (cancelled) {
					return;
				}
				setWalletClient(client);
				const resolvedAddress: Address | null = client.account?.address ?? null;
				if (!resolvedAddress) {
					console.error('Failed to resolve account address from wallet client. Wallet client からアカウントアドレスを取得できませんでした。');
				}
				setAccountAddress(resolvedAddress);
			} catch (error) {
				if (!cancelled) {
					console.error('Failed to create ICP wallet client:', error);
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
			const signed = await walletClient.signMessage({
				account: accountAddress,
				message,
			});
			setSignature(signed);
			const verified = await publicClient.verifyMessage({
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
