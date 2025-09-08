import {
  createActor as createTEcdsaBackendActor,
} from "../../../declarations/t_ecdsa_backend";
import {
  canisterId as INTERNET_IDENTITY_CANISTER_ID
} from "../../../declarations/internet_identity"
import {
  type Address,
  getAddress,
} from 'viem';
import { AuthClient } from '@dfinity/auth-client';

// Internet Identity provider URL
const network = process.env.DFX_NETWORK;
const identityProvider =
  network === 'ic'
    ? 'https://identity.ic0.app' // Mainnet
    : `http://${INTERNET_IDENTITY_CANISTER_ID}.localhost:4943`; // Local

export const login = async (): Promise<boolean> => {
  try {
    const authClient = await AuthClient.create();
    
    return new Promise((resolve) => {
      authClient.login({
        identityProvider,
        onSuccess: () => {
          console.log('Login successful');
          resolve(true);
        },
        onError: (error) => {
          console.error('Login failed:', error);
          resolve(false);
        }
      });
    });
  } catch (error) {
    console.error('Failed to create auth client:', error);
    return false;
  }
};

// Logout function
export const logout = async (): Promise<void> => {
  try {
    const authClient = await AuthClient.create();
    await authClient.logout();
    console.log('Logout successful');
  } catch (error) {
    console.error('Logout failed:', error);
  }
};

// Check if user is authenticated
export const isAuthenticated = async (): Promise<boolean> => {
  try {
    const authClient = await AuthClient.create();
    return await authClient.isAuthenticated();
  } catch (error) {
    console.error('Failed to check authentication status:', error);
    return false;
  }
};

// Get current user's principal
export const getCurrentPrincipal = async (): Promise<string | null> => {
  try {
    const authClient = await AuthClient.create();
    if (await authClient.isAuthenticated()) {
      const identity = authClient.getIdentity();
      return identity.getPrincipal().toString();
    }
    return null;
  } catch (error) {
    console.error('Failed to get current principal:', error);
    return null;
  }
};

// Create authenticated actor
export const createAuthenticatedActor = async () => {
  const authClient = await AuthClient.create();
  const identity = authClient.getIdentity();
  
  return createTEcdsaBackendActor(process.env.CANISTER_ID_T_ECDSA_BACKEND, {
    agentOptions: {
      identity
    }
  });
};

// Default unauthenticated actor for backwards compatibility
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
