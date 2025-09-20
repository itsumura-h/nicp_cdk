import { http, createConfig, custom } from 'wagmi';
import { mainnet, sepolia } from 'wagmi/chains';
import { injected } from 'wagmi/connectors';

// カスタムtransportを作成する関数
const createCustomTransport = () => {
  if (typeof window !== 'undefined') {
    // ICPプロバイダーを優先的に使用
    const icpProvider = (window as any).icpEthereum || window.ethereum;
    if (icpProvider) {
      console.log('Wagmi using ICP provider:', icpProvider);
      return custom(icpProvider);
    }
  }
  return http(); // フォールバック
};

// Wagmiの設定
export const wagmiConfig = createConfig({
  chains: [mainnet, sepolia],
  connectors: [
    injected({
      target: 'metaMask', // ICP Walletを含む注入されたプロバイダーを使用
    }),
  ],
  transports: {
    [mainnet.id]: createCustomTransport(),
    [sepolia.id]: createCustomTransport(),
  },
});

declare module 'wagmi' {
  interface Register {
    config: typeof wagmiConfig;
  }
}
