import { AuthClient } from "@dfinity/auth-client";
import { Identity, ActorSubclass, HttpAgent } from "@dfinity/agent";
import {
  canisterId as internetIdentityCanisterId,
  createActor as createInternetIdentityActor,
} from "../../../declarations/internet_identity";
import {
  canisterId as tEcdsaBackendCanisterId,
  createActor as createTEcdsaBackendActor,
} from "../../../declarations/t_ecdsa_backend";
import { _SERVICE as TEcdsaBackendService } from "../../../declarations/t_ecdsa_backend/t_ecdsa_backend.did";
import {
  type Address,
  type Chain,
  type Hex,
  type HttpTransport,
  type Transport,
  type LocalAccount,
  type RpcSchema,
  type SerializeTransactionFn,
  type SignableMessage,
  type Signature,
  type TransactionSerializable,
  type TypedData,
  type TypedDataDefinition,
  type WalletClient,
  createWalletClient,
  fromBytes,
  toBytes,
  getAddress,
  hashMessage,
  hashTypedData,
  keccak256,
  parseSignature,
  parseCompactSignature,
  compactSignatureToSignature,
  serializeSignature,
  serializeTransaction,
  toHex,
} from 'viem';
import { toAccount } from 'viem/accounts';
// import { icpPublicKeyToEthAddress, icpSignatureToEthSignature } from "./icpToEth"

const tEcdsaBackendActor = createTEcdsaBackendActor(process.env.CANISTER_ID_T_ECDSA_BACKEND);


export const getAccountAddress = async (): Promise<Address> => {
  try{
    await tEcdsaBackendActor.getPublicKey();
  }catch(e){
    await tEcdsaBackendActor.getNewPublicKey();
  }
  const publicKeyReply = await tEcdsaBackendActor.getEvmAddress();
  return getAddress(publicKeyReply);
};


export const signMessage = async ({ message }: { message: string }): Promise<string> => {
  const authClient = await AuthClient.create();
  console.log("=== icpWalletClient signMessage")
  if (!await authClient.isAuthenticated()) {
    return;
  }
  const signatureReply = await tEcdsaBackendActor.signWithEvm(message);
  return signatureReply;
};
