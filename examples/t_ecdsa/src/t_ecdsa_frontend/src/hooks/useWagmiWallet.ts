import { useAccount, useConnect, useDisconnect, useWalletClient } from 'wagmi';
import { useCallback, useEffect } from 'preact/hooks';
import { useIcpAuth } from './icpAuth';

export interface UseWagmiWalletResult {
  // Wagmi関連
  wagmiAddress: string | undefined;
  isWagmiConnected: boolean;
  isWagmiConnecting: boolean;
  wagmiWalletClient: any;
  connectWagmi: () => void;
  disconnectWagmi: () => void;
  
  // ICP認証関連
  icpAddress: string | undefined;
  isIcpAuthenticated: boolean;
  icpWalletClient: any;
  loginIcp: () => Promise<boolean>;
  logoutIcp: () => Promise<void>;
}

export const useWagmiWallet = (): UseWagmiWalletResult => {
  // Wagmiフック
  const { address: wagmiAddress, isConnected: isWagmiConnected } = useAccount();
  const { connect, connectors, isPending: isWagmiConnecting } = useConnect();
  const { disconnect: disconnectWagmi } = useDisconnect();
  const { data: wagmiWalletClient } = useWalletClient();
  
  // ICP認証フック
  const {
    isAuthenticated: isIcpAuthenticated,
    walletClient: icpWalletClient,
    login: loginIcp,
    logout: logoutIcp,
  } = useIcpAuth();

  // ICP認証されたアドレスを取得
  const icpAddress = icpWalletClient?.account?.address;

  // Wagmi接続関数
  const connectWagmi = useCallback(() => {
    const injectedConnector = connectors.find(connector => connector.type === 'injected');
    if (injectedConnector) {
      connect({ connector: injectedConnector });
    } else {
      console.error('Injected connector not found');
    }
  }, [connect, connectors]);

  // ICP認証が成功した後、自動的にWagmiに接続を試行
  useEffect(() => {
    if (isIcpAuthenticated && icpWalletClient && !isWagmiConnected && typeof window !== 'undefined' && window.ethereum) {
      // 少し遅延してからWagmi接続を試行（Ethereumプロバイダーが完全に設定されるのを待つ）
      const timer = setTimeout(() => {
        connectWagmi();
      }, 1000);
      
      return () => clearTimeout(timer);
    }
  }, [isIcpAuthenticated, icpWalletClient, isWagmiConnected, connectWagmi]);

  return {
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
  };
};
