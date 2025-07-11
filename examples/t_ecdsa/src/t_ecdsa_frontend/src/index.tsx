import { hydrate, prerender as ssr } from 'preact-iso';
import { useState, useEffect } from 'preact/hooks';
import { Address } from 'viem';
import { getAccountAddress, signMessage } from './hooks/icp';

export function App() {
	const [accountAddress, setAccountAddress] = useState<Address | null>(null);
	const [message, setMessage] = useState<string | null>(null);
	const [signature, setSignature] = useState<string | null>(null);

	useEffect(() => {
		(async()=>{
			const address = await getAccountAddress();
			setAccountAddress(address);
		})()
	}, []);

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
					<button onClick={() => signMessage({ message })}>Sign</button>
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
