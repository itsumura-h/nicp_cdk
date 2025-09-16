import { AuthClient } from "@dfinity/auth-client";
import { HttpAgent } from "@dfinity/agent";

import {
  canisterId as internetIdentityCanisterId,
} from "../../../declarations/internet_identity";

import {
  canisterId as callSolidityBackendCanisterId,
  createActor as createCallSolidityBackendActor,
} from "../../../declarations/call_solidity_backend";

import type { _SERVICE as CallSolidityBackendService } from "../../../declarations/call_solidity_backend/call_solidity_backend.did";

import {
  type Address,
  type Chain,
  type Hex,
  type LocalAccount,
  type RpcSchema,
  type SerializeTransactionFn,
  type SignableMessage,
  type Transport,
  type TransactionSerializable,
  type TypedData,
  type TypedDataDefinition,
  type WalletClient,
  createWalletClient,
  getAddress,
  hashTypedData,
  keccak256,
  serializeTransaction,
  toHex,
} from 'viem';
import { toAccount } from 'viem/accounts';


// Create Actor bound to the current authenticated identity
async function createActorWithAuth(authClient: AuthClient) {
  const identity = authClient.getIdentity();
  const agent = await HttpAgent.create({ identity });
  const actor = createCallSolidityBackendActor(
    callSolidityBackendCanisterId,
    { agent },
  ) as unknown as import("../../../declarations/call_solidity_backend").ActorSubclass<CallSolidityBackendService>;
  return actor;
}


const toIcpAccount = async (authClient: AuthClient): Promise<LocalAccount> => {
  const getAccountAddress = async (): Promise<Address> => {
    if (!await authClient.isAuthenticated()) return undefined as unknown as Address;

    const actor = await createActorWithAuth(authClient);

    // Prefer canister-side address derivation
    if ('getEvmAddress' in (actor as any)) {
      const addr = await (actor as any).getEvmAddress();
      if (addr && typeof addr === 'string' && addr.length > 0) {
        return getAddress(addr as string);
      }
    }

    // Fallback: if not available, fail fast with guidance
    throw new Error('getEvmAddress not available on canister. Please expose it and regenerate declarations.');
  };

  const address = await getAccountAddress();

  const signMessage = async ({ message }: { message: SignableMessage }): Promise<Hex> => {
    if (!await authClient.isAuthenticated()) return undefined as unknown as Hex;
    const actor = await createActorWithAuth(authClient);

    // Use canister-side EIP-191 signing that returns 65-byte Ethereum signature (r + s + v)
    if ('signWithEthereum' in (actor as any)) {
      const sig = await (actor as any).signWithEthereum(message.toString());
      return sig as Hex;
    }

    // Fallback or missing API
    throw new Error('signWithEthereum not available on canister. Please expose it and regenerate declarations.');
  };

  const signTransaction = async <TTransactionSerializable extends TransactionSerializable>(
    transaction: TTransactionSerializable,
    args?: { serializer?: SerializeTransactionFn<TTransactionSerializable> }
  ): Promise<Hex> => {
    const serializer = args?.serializer ?? serializeTransaction;
    if (!await authClient.isAuthenticated()) return undefined as unknown as Hex;
    const actor = await createActorWithAuth(authClient);

    // Create transaction preimage & hash
    const unsignedSerialized = serializer(transaction);
    const txHash = keccak256(unsignedSerialized);

    // Expect a canister method that signs a 32-byte hash and returns an Ethereum 65-byte signature
    const maybeSignHashWithEthereum = (actor as any).signHashWithEthereum || (actor as any).signTxHashWithEthereum || (actor as any).signHash;

    if (!maybeSignHashWithEthereum) {
      throw new Error('signHashWithEthereum (or signTxHashWithEthereum/signHash) not available on canister. Please add a hash-signing endpoint to avoid double-hashing and regenerate declarations.');
    }

    // txHash is 0x-prefixed 32-byte hex; pass as-is
    const signature65 = await maybeSignHashWithEthereum(txHash);

    // serializer(transaction, signature) -> raw signed tx
    return serializer(transaction, signature65 as Hex);
  };

  const signTypedData = async <typedData extends TypedData | Record<string, unknown>, primaryType extends keyof typedData | 'EIP712Domain' = keyof typedData>(
    _typedData: TypedDataDefinition<typedData, primaryType>
  ): Promise<Hex> => {
    if (!await authClient.isAuthenticated()) return undefined as unknown as Hex;
    const actor = await createActorWithAuth(authClient);
    const typedDataHash = hashTypedData(_typedData);

    const maybeSignHashWithEthereum = (actor as any).signHashWithEthereum || (actor as any).signTxHashWithEthereum || (actor as any).signHash;
    if (!maybeSignHashWithEthereum) {
      throw new Error('signHashWithEthereum (or signTxHashWithEthereum/signHash) not available on canister for typed data.');
    }

    const signature65 = await maybeSignHashWithEthereum(typedDataHash);
    return signature65 as Hex;
  };

  return toAccount({ address, signMessage, signTransaction, signTypedData });
};


export type IcpWalletClient = WalletClient<Transport, Chain, LocalAccount, RpcSchema>;

const createIcpWalletClient = async (arg: { authClient: AuthClient, chain: Chain, transport: Transport, }): Promise<IcpWalletClient> => {
  const icpAccount = await toIcpAccount(arg.authClient);
  const walletClient = createWalletClient({
    account: icpAccount,
    chain: arg.chain,
    transport: arg.transport,
  });
  return walletClient as IcpWalletClient;
};

export async function createIcpWallet({ authClient, chain, transport }: { authClient: AuthClient, chain: Chain, transport: Transport, }): Promise<{ walletClient: IcpWalletClient, principal: string }> {
  if (!(await authClient.isAuthenticated())) {
    await new Promise<void>((resolve, reject) => {
      authClient.login({
        identityProvider: `http://${internetIdentityCanisterId}.localhost:4943`,
        onSuccess: () => resolve(),
        onError: (error) => reject(error),
      });
    });
  }

  const identity = authClient.getIdentity();
  const principal = identity?.getPrincipal().toText() || '';
  const walletClient = await createIcpWalletClient({ authClient, chain, transport });
  return { walletClient, principal };
}

export { createIcpWalletClient };

