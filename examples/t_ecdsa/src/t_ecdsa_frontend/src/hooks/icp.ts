import {
  createActor as createTEcdsaBackendActor,
} from "../../../declarations/t_ecdsa_backend";
import {
  type Address,
  getAddress,
} from 'viem';

const tEcdsaBackendActor = createTEcdsaBackendActor(process.env.CANISTER_ID_T_ECDSA_BACKEND);


export const getEvmAddress = async (): Promise<Address> => {
  try{
    await tEcdsaBackendActor.getPublicKey();
  }catch(e){
    await tEcdsaBackendActor.getNewPublicKey();
  }
  const publicKeyReply = await tEcdsaBackendActor.getEvmAddress();
  return getAddress(publicKeyReply);
};


export const signMessage = async ({ message }: { message: string }): Promise<Address> => {
  const signatureReply = await tEcdsaBackendActor.signWithEthereum(message);
  return signatureReply as Address;
};
