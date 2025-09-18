import { AuthClient } from '@dfinity/auth-client';
import {
  canisterId as tEcdsaBackendCanisterId,
  createActor as createTEcdsaBackendActor,
} from '../../../declarations/t_ecdsa_backend';
import type { _SERVICE as TEcdsaBackendService } from '../../../declarations/t_ecdsa_backend/t_ecdsa_backend.did';
import {
  type Address,
  type Chain,
  type Hex,
  type LocalAccount,
  type RpcSchema,
  type SerializeTransactionFn,
  type SignableMessage,
  type TransactionSerializable,
  type Transport,
  type TypedData,
  type TypedDataDefinition,
  type WalletClient,
  createWalletClient,
  getAddress,
  http,
} from 'viem';
import { toAccount } from 'viem/accounts';

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
    const normalisedMessage = normaliseSignableMessage(message);
    const signature = await actor.signWithEthereum(normalisedMessage);
    return signature as Hex;
  };

  const signTransaction = async <
    TTransactionSerializable extends TransactionSerializable,
  >(
    _transaction: TTransactionSerializable,
    _args?: {
      serializer?: SerializeTransactionFn<TTransactionSerializable>;
    },
  ): Promise<Hex> => {
    throw new Error('Transaction signing is not supported yet for ICP wallet.');
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

export type IcpWalletClient = WalletClient;

export interface CreateIcpWalletOptions {
  authClient: AuthClient;
  chain: Chain;
  transport?: Transport | undefined;
}

export async function createIcpWalletClient(options: CreateIcpWalletOptions): Promise<IcpWalletClient> {
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
