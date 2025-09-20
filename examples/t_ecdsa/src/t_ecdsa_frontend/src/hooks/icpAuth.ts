import { useCallback, useEffect, useRef, useState } from 'preact/hooks';
import { AuthClient } from '@dfinity/auth-client';
import {
  canisterId as INTERNET_IDENTITY_CANISTER_ID,
} from '../../../declarations/internet_identity';
import { createIcpWalletClient, type IcpWalletClient } from './icpWalletClient';
import { mainnet } from 'viem/chains';
import type { Hex, Address, SignableMessage, Signature } from 'viem';
import { hashMessage, serializeSignature, hexToBytes } from 'viem';
import {
  canisterId as tEcdsaBackendCanisterId,
  createActor as createTEcdsaBackendActor,
} from '../../../declarations/t_ecdsa_backend';
import type { _SERVICE as TEcdsaBackendService } from '../../../declarations/t_ecdsa_backend/t_ecdsa_backend.did';

const network = process.env.DFX_NETWORK;
export const identityProvider =
  network === 'ic'
    ? 'https://identity.ic0.app'
    : `http://${INTERNET_IDENTITY_CANISTER_ID}.localhost:4943`;

// EIP-1193準拠のEthereumプロバイダーインターフェース
interface EthereumProvider {
  isMetaMask?: boolean;
  request(args: { method: string; params?: unknown[] }): Promise<unknown>;
  on(eventName: string, handler: (...args: unknown[]) => void): void;
  removeListener(eventName: string, handler: (...args: unknown[]) => void): void;
  emit(eventName: string, ...args: unknown[]): void;
}

// ICP用Ethereumプロバイダーの実装
class IcpEthereumProvider implements EthereumProvider {
  public readonly isIcpProvider = true; // ICP識別用
  private walletClient: IcpWalletClient | null = null;
  private authClient: AuthClient | null = null;
  private backendActor: TEcdsaBackendService | null = null;
  private eventListeners: Map<string, Set<(...args: unknown[]) => void>> = new Map();
  private accounts: string[] = [];
  private chainId = '0x1'; // Ethereum mainnet
  
  constructor(walletClient: IcpWalletClient | null = null, authClient: AuthClient | null = null) {
    this.walletClient = walletClient;
    this.authClient = authClient;
    
    if (authClient) {
      this.initializeBackendActor(authClient);
    }
    
    if (walletClient?.account) {
      this.accounts = [walletClient.account.address];
    }
  }

  private initializeBackendActor(authClient: AuthClient) {
    const identity = authClient.getIdentity();
    this.backendActor = createTEcdsaBackendActor(tEcdsaBackendCanisterId, {
      agentOptions: {
        identity,
      },
    });
  }

  private async ensurePublicKey(): Promise<void> {
    if (!this.backendActor) {
      throw new Error('Backend actor not initialized');
    }
    
    try {
      await this.backendActor.getPublicKey();
    } catch (error) {
      console.warn('Failed to fetch existing public key, requesting a new one.', error);
      await this.backendActor.getNewPublicKey();
    }
  }

  private async getIcpAddress(): Promise<Address> {
    if (!this.backendActor) {
      throw new Error('Backend actor not initialized');
    }

    await this.ensurePublicKey();
    
    try {
      const evmAddress = await this.backendActor.getEvmAddress() as Address;
      if (!evmAddress) {
        throw new Error('Failed to resolve Ethereum address from canister.');
      }
      return evmAddress;
    } catch (error) {
      console.warn('Failed to fetch Ethereum address, requesting a new one.', error);
      await this.backendActor.getNewPublicKey();
      const evmAddress = await this.backendActor.getEvmAddress() as Address;
      if (!evmAddress) {
        throw new Error('Failed to resolve Ethereum address from canister.');
      }
      return evmAddress;
    }
  }

  private async signWithIcp(message: SignableMessage): Promise<Hex> {
    if (!this.backendActor) {
      throw new Error('Backend actor not initialized');
    }

    const hash = hashMessage(message);
    const hashBytes = hexToBytes(hash);
    const signature = await this.backendActor.signWithEvmWallet(hashBytes);
    
    // 0xプレフィックスを削除
    const sigHex = signature.startsWith('0x') ? signature.slice(2) : signature;
    
    // 署名は65バイト (130文字) である必要がある
    if (sigHex.length !== 130) {
      throw new Error(`Invalid signature length: ${sigHex.length}, expected 130`);
    }
    
    const r = '0x' + sigHex.slice(0, 64);
    const s = '0x' + sigHex.slice(64, 128);
    let v = parseInt(sigHex.slice(128, 130), 16);
    
    // Ethereumの署名では、v値は27または28である必要がある
    // recovery IDが0または1の場合、27を加算する
    if (v < 27) {
      v += 27;
    }
    
    console.log('ICP Signature - r:', r, 's:', s, 'v:', v);
    
    const sig: Signature = {
      r: r as Hex,
      s: s as Hex,
      v: BigInt(v),
    };
    
    return serializeSignature(sig);
  }

  async updateWalletClient(walletClient: IcpWalletClient | null, authClient: AuthClient | null = null) {
    this.walletClient = walletClient;
    
    if (authClient) {
      this.authClient = authClient;
      this.initializeBackendActor(authClient);
      
      try {
        // ICPキャニスターからアドレスを取得
        const icpAddress = await this.getIcpAddress();
        this.accounts = [icpAddress];
        console.log('ICP Address from canister:', icpAddress);
      } catch (error) {
        console.error('Failed to get ICP address:', error);
        this.accounts = [];
      }
    } else if (walletClient?.account) {
      this.accounts = [walletClient.account.address];
    } else {
      this.accounts = [];
    }
    
    this.emit('accountsChanged', this.accounts);
  }

  async request(args: { method: string; params?: unknown[] }): Promise<unknown> {
    const { method, params = [] } = args;

    switch (method) {
      case 'eth_requestAccounts':
      case 'eth_accounts': {
        // ICPキャニスターからアドレスを取得
        if (this.backendActor && this.accounts.length === 0) {
          try {
            const icpAddress = await this.getIcpAddress();
            this.accounts = [icpAddress];
            this.emit('accountsChanged', this.accounts);
          } catch (error) {
            console.error('Failed to get accounts from ICP:', error);
          }
        }
        return this.accounts;
      }

      case 'eth_chainId':
        return this.chainId;

      case 'personal_sign': {
        if (!this.backendActor) {
          throw new Error('ICP backend not connected');
        }
        const [message, address] = params as [string, string];
        
        // アドレス確認
        if (this.accounts.length === 0) {
          const icpAddress = await this.getIcpAddress();
          this.accounts = [icpAddress];
        }
        
        if (address.toLowerCase() !== this.accounts[0].toLowerCase()) {
          throw new Error('Address mismatch');
        }
        
        // ICPキャニスターで署名
        return await this.signWithIcp(message);
      }

      case 'eth_signTypedData_v4': {
        if (!this.backendActor) {
          throw new Error('ICP backend not connected');
        }
        throw new Error('Typed data signing is not supported yet');
      }

      case 'eth_sendTransaction': {
        if (!this.walletClient) {
          throw new Error('Wallet client not available for transactions');
        }
        const [transaction] = params as [any];
        const hash = await this.walletClient.sendTransaction(transaction);
        return hash;
      }

      case 'eth_sign': {
        if (!this.backendActor) {
          throw new Error('ICP backend not connected');
        }
        const [address, message] = params as [string, string];
        
        // アドレス確認
        if (this.accounts.length === 0) {
          const icpAddress = await this.getIcpAddress();
          this.accounts = [icpAddress];
        }
        
        if (address.toLowerCase() !== this.accounts[0].toLowerCase()) {
          throw new Error('Address mismatch');
        }
        
        // ICPキャニスターで署名
        return await this.signWithIcp(message);
      }

      default:
        throw new Error(`Unsupported method: ${method}`);
    }
  }

  on(eventName: string, handler: (...args: unknown[]) => void): void {
    if (!this.eventListeners.has(eventName)) {
      this.eventListeners.set(eventName, new Set());
    }
    this.eventListeners.get(eventName)!.add(handler);
  }

  removeListener(eventName: string, handler: (...args: unknown[]) => void): void {
    const listeners = this.eventListeners.get(eventName);
    if (listeners) {
      listeners.delete(handler);
    }
  }

  emit(eventName: string, ...args: unknown[]): void {
    const listeners = this.eventListeners.get(eventName);
    if (listeners) {
      listeners.forEach(handler => {
        try {
          handler(...args);
        } catch (error) {
          console.error(`Error in event handler for ${eventName}:`, error);
        }
      });
    }
  }
}

// グローバルなプロバイダーインスタンス
let globalProvider: IcpEthereumProvider | null = null;

// window.ethereumを注入する関数
const injectEthereumProvider = async (walletClient: IcpWalletClient | null = null, authClient: AuthClient | null = null) => {
  if (typeof window === 'undefined') {
    return;
  }

  if (!globalProvider) {
    globalProvider = new IcpEthereumProvider(walletClient, authClient);
    
    // 既存のwindow.ethereumをバックアップ
    const existingEthereum = (window as any).ethereum;
    
    // 既存のプロバイダーがある場合は、originalEthereumにバックアップ
    if (existingEthereum && existingEthereum !== globalProvider) {
      (window as any).originalEthereum = existingEthereum;
      console.log('Existing ethereum provider backed up to window.originalEthereum');
    }
    
    // ICPプロバイダーを確実に設定
    (window as any).icpEthereum = globalProvider;
    (window as any).ethereum = globalProvider;
    
    console.log('ICP Ethereum provider injected as window.ethereum and window.icpEthereum');
    
    // 定期的にプロバイダーの状態をチェックし、必要に応じて再注入
    const checkAndReinject = () => {
      const currentEthereum = (window as any).ethereum;
      const currentIcpEthereum = (window as any).icpEthereum;
      
      // window.ethereumがICPプロバイダーでない場合は再注入
      if (!currentEthereum || !currentEthereum.isIcpProvider) {
        console.log('Re-injecting ICP provider to window.ethereum');
        (window as any).ethereum = globalProvider;
      }
      
      // window.icpEthereumが失われた場合は再注入
      if (!currentIcpEthereum || !currentIcpEthereum.isIcpProvider) {
        console.log('Re-injecting ICP provider to window.icpEthereum');
        (window as any).icpEthereum = globalProvider;
      }
    };
    
    // 1秒ごとにチェック（開発時のみ）
    if (process.env.NODE_ENV === 'development') {
      setInterval(checkAndReinject, 1000);
    }
    
    // EIP-6963イベントを発火してプロバイダーの存在を通知
    const announceEvent = new CustomEvent('eip6963:announceProvider', {
      detail: {
        info: {
          uuid: 'icp-wallet-provider',
          name: 'ICP Wallet',
          icon: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="%23007bff"/></svg>',
          rdns: 'icp.wallet',
        },
        provider: globalProvider,
      },
    });
    window.dispatchEvent(announceEvent);
  } else {
    await globalProvider.updateWalletClient(walletClient, authClient);
  }
};

export interface UseIcpAuthResult {
  authClient: AuthClient | null;
  identityProvider: string;
  isAuthenticated: boolean;
  isLoading: boolean;
  principal: string | null;
  walletClient: IcpWalletClient | null;
  login: () => Promise<boolean>;
  logout: () => Promise<void>;
  refresh: () => Promise<void>;
}

export const useIcpAuth = (): UseIcpAuthResult => {
  const [authClient, setAuthClient] = useState<AuthClient | null>(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [principal, setPrincipal] = useState<string | null>(null);
  const [walletClient, setWalletClient] = useState<IcpWalletClient | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const clientPromiseRef = useRef<Promise<AuthClient> | null>(null);

  const refreshSession = useCallback(async (client: AuthClient) => {
    try {
      const authenticated = await client.isAuthenticated();
      setIsAuthenticated(authenticated);
      if (authenticated) {
        const currentPrincipal = client.getIdentity().getPrincipal().toString();
        setPrincipal(currentPrincipal);
        
        // 認証成功時にウォレットクライアントを作成し、Ethereumプロバイダーを注入
        try {
          const icpWalletClient = await createIcpWalletClient({
            authClient: client,
            chain: mainnet,
          });
          setWalletClient(icpWalletClient);
          await injectEthereumProvider(icpWalletClient, client);
        } catch (walletError) {
          console.error('Failed to create wallet client:', walletError);
          setWalletClient(null);
          await injectEthereumProvider(null, null);
        }
      } else {
        setPrincipal(null);
        setWalletClient(null);
        await injectEthereumProvider(null, null);
      }
    } catch (error) {
      console.error('Failed to refresh authentication session:', error);
      setIsAuthenticated(false);
      setPrincipal(null);
      setWalletClient(null);
      await injectEthereumProvider(null, null);
    }
  }, []);

  const ensureAuthClient = useCallback(async (): Promise<AuthClient> => {
    if (authClient) {
      return authClient;
    }

    if (typeof window === 'undefined') {
      throw new Error('Auth client is only available in the browser.');
    }

    if (!clientPromiseRef.current) {
      clientPromiseRef.current = AuthClient.create();
    }

    try {
      const client = await clientPromiseRef.current;
      setAuthClient((current) => current ?? client);
      return client;
    } catch (error) {
      clientPromiseRef.current = null;
      throw error;
    }
  }, [authClient]);

  useEffect(() => {
    if (typeof window === 'undefined') {
      setIsLoading(false);
      return;
    }

    let cancelled = false;

    ensureAuthClient()
      .then((client) => {
        if (cancelled) {
          return;
        }
        return refreshSession(client);
      })
      .catch((error) => {
        if (!cancelled) {
          console.error('Failed to initialise auth client:', error);
        }
      })
      .finally(() => {
        if (!cancelled) {
          setIsLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [ensureAuthClient, refreshSession]);

  const login = useCallback(async () => {
    try {
      const client = await ensureAuthClient();

      return await new Promise<boolean>((resolve) => {
        client.login({
          identityProvider,
          onSuccess: async () => {
            await refreshSession(client);
            resolve(true);
          },
          onError: (error) => {
            console.error('Login failed:', error);
            resolve(false);
          },
        });
      });
    } catch (error) {
      console.error('Failed to start login flow:', error);
      return false;
    }
  }, [ensureAuthClient, refreshSession]);

  const logout = useCallback(async () => {
    try {
      const client = await ensureAuthClient();
      await client.logout();
      await refreshSession(client);
    } catch (error) {
      console.error('Logout failed:', error);
    }
  }, [ensureAuthClient, refreshSession]);

  const refresh = useCallback(async () => {
    try {
      const client = await ensureAuthClient();
      await refreshSession(client);
    } catch (error) {
      console.error('Failed to refresh authentication state:', error);
    }
  }, [ensureAuthClient, refreshSession]);

  return {
    authClient,
    identityProvider,
    isAuthenticated,
    isLoading,
    principal,
    walletClient,
    login,
    logout,
    refresh,
  };
};
