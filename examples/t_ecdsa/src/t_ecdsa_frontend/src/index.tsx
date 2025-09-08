import { hydrate, prerender as ssr } from 'preact-iso';
import { useState, useEffect } from 'preact/hooks';
import { Address, createPublicClient, http } from 'viem';
import { mainnet } from 'viem/chains';
import { getEvmAddress, signMessage, login, logout, isAuthenticated, getCurrentPrincipal } from './hooks/icp';

const publicClient = createPublicClient({
	chain: mainnet,
	transport: http(),
});

export function App() {
	const [isLogin, setIsLogin] = useState<boolean>(false);
	const [principal, setPrincipal] = useState<string | null>(null);
	const [accountAddress, setAccountAddress] = useState<Address | null>(null);
	const [message, setMessage] = useState<string | null>("hello world");
	const [signature, setSignature] = useState<string | null>(null);
	const [isValid, setIsValid] = useState<boolean | null>(null);

	useEffect(() => {
		(async()=>{
			// Check authentication status on load
			const authenticated = await isAuthenticated();
			setIsLogin(authenticated);
			
			if (authenticated) {
				// Get principal and address only if authenticated
				const principalId = await getCurrentPrincipal();
				setPrincipal(principalId);
				
				const address = await getEvmAddress();
				setAccountAddress(address);
			} else {
				// Clear data if not authenticated
				setPrincipal(null);
				setAccountAddress(null);
			}
		})()
	}, []);

	const handleLogin = async () => {
		if (isLogin) {
			// Logout
			await logout();
			setIsLogin(false);
			setPrincipal(null);
			setAccountAddress(null);
		} else {
			// Login
			const success = await login();
			if (success) {
				setIsLogin(true);
				
				// Get principal and address after successful login
				const principalId = await getCurrentPrincipal();
				setPrincipal(principalId);
				
				const address = await getEvmAddress();
				setAccountAddress(address);
			}
		}
	};

	const handleSign = async () => {
		const signature = await signMessage({ message });
		setSignature(signature);
		const isValid = await publicClient.verifyMessage({
			address: accountAddress as Address,
			message: message,
			signature: signature,
		});
		setIsValid(isValid);
	}

	return (
		<main>
			<article>
				<h2>T-ECDSA</h2>
				<button onClick={handleLogin}>
					{isLogin ? 'Logout' : 'Login with Internet Identity'}
				</button>
				<p>Status: {isLogin ? 'Authenticated' : 'Not authenticated'}</p>
				{isLogin && (
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
					<button onClick={handleSign}>Sign</button>
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
