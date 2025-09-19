import {
  type Address,
  type Chain,
  type Hex,
  type LocalAccount,
  type RpcSchema,
  type SerializeTransactionFn,
  type SignableMessage,
  type Signature,
  type TransactionSerializable,
  type Transport,
  type TypedData,
  type TypedDataDefinition,
  type WalletClient,
  createWalletClient,
  fromBytes,
  getAddress,
  http,
  keccak256,
  serializeTransaction,
  hashMessage,
  serializeSignature,
  hexToBytes,
} from 'viem';
import { toAccount } from 'viem/accounts';
import { AuthClient } from '@dfinity/auth-client';
import {
  canisterId as tEcdsaBackendCanisterId,
  createActor as createTEcdsaBackendActor,
} from '../../../declarations/t_ecdsa_backend';
import type { _SERVICE as TEcdsaBackendService } from '../../../declarations/t_ecdsa_backend/t_ecdsa_backend.did';

const createBackendActor = (authClient: AuthClient): TEcdsaBackendService => {
  const identity = authClient.getIdentity();
  return createTEcdsaBackendActor(tEcdsaBackendCanisterId, {
    agentOptions: {
      identity,
    },
  });
};

const ensurePublicKey = async (actor: TEcdsaBackendService) => {
  try {
    await actor.getPublicKey();
  } catch (error) {
    console.warn('Failed to fetch existing public key, requesting a new one.', error);
    await actor.getNewPublicKey();
  }
};

const resolveAddress = async (actor: TEcdsaBackendService): Promise<Address> => {
  const evmAddress = await (async ():Promise<Address>=>{
    try{
      return await actor.getEvmAddress();
    } catch (error) {
      console.warn('Failed to fetch Ethereum address, requesting a new one.', error);
      // 公開鍵を生成してから、EVMアドレスを再取得
      await actor.getNewPublicKey();
      return await actor.getEvmAddress();
    }
  })()

  if (!evmAddress) {
    throw new Error('Failed to resolve Ethereum address from canister.');
  }
  return evmAddress;
};

const normaliseSignableMessage = (message: SignableMessage): string => {
  if (typeof message === 'string') {
    return message;
  }

  if (typeof message.raw === 'string') {
    throw new Error('Hex-encoded messages are not supported yet.');
  }

  throw new Error('Binary signable messages are not supported yet.');
};

const toIcpAccount = async (authClient: AuthClient): Promise<LocalAccount> => {
  const actor = createBackendActor(authClient);
  await ensurePublicKey(actor);
  const address = await resolveAddress(actor);

  const signMessage = async ({
    message,
  }: {
    message: SignableMessage;
  }): Promise<Hex> => {
    const hash = hashMessage(message);
    const hashBytes = hexToBytes(hash);
    const signature = await actor.signWithEvmWallet(hashBytes);
    
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
    
    console.log('Parsed signature - r:', r, 's:', s, 'v:', v);
    
    const sig: Signature = {
      r: r as Hex,
      s: s as Hex,
      v: BigInt(v),
    };
    
    return serializeSignature(sig);
  };

  const signTransaction = async<
    TTransactionSerializable extends TransactionSerializable,
  >(
    transaction: TTransactionSerializable,
    args?: {
      serializer?: SerializeTransactionFn<TTransactionSerializable>;
    }
  ): Promise<Hex> => {
    if (!args?.serializer) {
      return signTransaction(transaction, {
        serializer: serializeTransaction,
      });
    }
    const serialized = args.serializer(transaction);
    const hash = keccak256(serialized);
    const hashBytes = hexToBytes(hash);
    const signature = await actor.signWithEvmWallet(hashBytes);

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
    
    console.log('Parsed signature - r:', r, 's:', s, 'v:', v);
    
    const sig: Signature = {
      r: r as Hex,
      s: s as Hex,
      v: BigInt(v),
    };
    
    return args.serializer(transaction, sig);
  };

  const signTypedData = async <
    typedData extends TypedData | Record<string, unknown>,
    primaryType extends keyof typedData | 'EIP712Domain' = keyof typedData,
  >(
    _typedData: TypedDataDefinition<typedData, primaryType>,
  ): Promise<Hex> => {
    throw new Error('Typed data signing is not supported yet for ICP wallet.');
  };

  return toAccount({
    address,
    signMessage,
    signTransaction,
    signTypedData,
  });
};

export interface CreateIcpWalletOptions {
  authClient: AuthClient;
  chain: Chain;
  transport?: Transport | undefined;
}

export async function createIcpWalletClient(options: CreateIcpWalletOptions): Promise<WalletClient> {
  if (!(await options.authClient.isAuthenticated())) {
    throw new Error('Auth client must be authenticated before creating wallet client.');
  }

  const account = await toIcpAccount(options.authClient);
  const walletClient = createWalletClient({
    account,
    chain: options.chain,
    transport: options.transport ?? http(), // transportがundefinedまたは未指定の場合はダミー値を使用
  });

  return walletClient;
}

export type IcpWalletClient = WalletClient;
