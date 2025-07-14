import { hydrate, prerender as ssr } from 'preact-iso';
import { useState, useEffect } from 'preact/hooks';
import { Address, createPublicClient, http } from 'viem';
import { mainnet } from 'viem/chains';
import { getEvmAddress, signMessage } from './hooks/icp';

const publicClient = createPublicClient({
	chain: mainnet,
	transport: http(),
});

export function App() {
	const [accountAddress, setAccountAddress] = useState<Address | null>(null);
	const [message, setMessage] = useState<string | null>("hello world");
	const [signature, setSignature] = useState<string | null>(null);
	const [isValid, setIsValid] = useState<boolean | null>(null);

	useEffect(() => {
		(async()=>{
			const address = await getEvmAddress();
			setAccountAddress(address);
		})()
	}, []);

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
				<p>Account Address: {accountAddress}</p>
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
