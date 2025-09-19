// 参考
// デジタル署名の作成と検証
// https://cloud.google.com/kms/docs/create-validate-signatures?hl=ja#kms-sign-asymmetric-nodejs
// ViemとKMSを利用したトランザクション署名
// https://zenn.dev/noplan_inc/articles/98cebea1341ab6
// thirdweb-dev/engine
// https://github.com/thirdweb-dev/engine/blob/main/src/server/utils/wallets/get-gcp-kms-account.ts

// gcloudコマンドでログインする
// gcloud init
// gcloud config set project jpyc-apps-dev
// gcloud auth application-default login
// ブラウザを開いてログインし、出てきたコードをターミナルに入力すると鍵ファイルが作られる
// 鍵が作成されたらKMSを実行できる
// 参考: ローカル開発環境に ADC を設定する
// https://cloud.google.com/docs/authentication/set-up-adc-local-dev-environment?hl=ja

// 鍵の作成
// 保護レベル: HSM
// 鍵マテリアル: HSM により生成
// 目的: 非対称な署名
// アルゴリズム: Elliptic Curve secp256k1 - SHA256 ダイジェスト


import { CloudKmsSigner } from '@cloud-cryptographic-wallet/cloud-kms-signer';
import { Bytes } from '@cloud-cryptographic-wallet/signer';
import {
  createWalletClient,
  fromBytes,
  getAddress,
  hashMessage,
  hashTypedData,
  keccak256,
  serializeSignature,
  serializeTransaction,
  type Address,
  type Chain,
  type Hex,
  type HttpTransport,
  type LocalAccount,
  type RpcSchema,
  type SerializeTransactionFn,
  type SignableMessage,
  type Signature,
  type TransactionSerializable,
  type TypedData,
  type TypedDataDefinition,
  type WalletClient,
} from 'viem';
import { toAccount } from 'viem/accounts';


const toKmsAccount = async (keyName: string): Promise<LocalAccount> => {
  const createSigner = (keyName: string) => {
    if (keyName.split('/').length !== 10) {
      throw new Error('Keynameの長さが正しくありません。鍵のバージョンまで含めてリソース名をコピーしてください。');
    }
    const signer = new CloudKmsSigner(keyName)
    return signer
  }

  const getAccountAddress = async (): Promise<Address> => {
    const signer = createSigner(keyName)
    const address = (await signer.getPublicKey()).toAddress();
    return getAddress(address.toString());
  };

  const address = await getAccountAddress();

  const signMessage = async ({ message }: { message: SignableMessage }): Promise<Hex> => {
    const signer = createSigner(keyName)
    const hash = Bytes.fromString(hashMessage(message));
    const signature = await signer.sign(hash);
    return serializeSignature({
      r: fromBytes(signature.r.asUint8Array, 'hex'),
      s: fromBytes(signature.s.asUint8Array, 'hex'),
      v: BigInt(signature.v),
    });
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
    const signer = createSigner(keyName)
    const serialized = args.serializer(transaction);
    const hash = keccak256(serialized);
    const signature = await signer.sign(Bytes.fromString(hash));
    const sig: Signature = {
      r: fromBytes(signature.r.asUint8Array, 'hex'),
      s: fromBytes(signature.s.asUint8Array, 'hex'),
      v: BigInt(signature.v),
    };
    return args.serializer(transaction, sig);
  };

  const signTypedData = async <
    typedData extends TypedData | Record<string, unknown>,
    primaryType extends keyof typedData | "EIP712Domain" = keyof typedData,
  >(_typedData: TypedDataDefinition<typedData, primaryType>): Promise<Hex> => {
    const signer = createSigner(keyName)
    const typedDataHash = hashTypedData(_typedData);
    const signature = await signer.sign(Bytes.fromString(typedDataHash));
    return signature.bytes.toString() as Hex;
  }

  return toAccount({
    address,
    signMessage,
    signTransaction,
    signTypedData,
    publicKey: address,
  });
};

export type GcpWalletClient = WalletClient<HttpTransport, Chain, LocalAccount, RpcSchema>;

export const createGcpWalletClient = async (arg: { keyName: string, chain: Chain, transport: HttpTransport, }): Promise<GcpWalletClient> => {
  const kmsAccount = await toKmsAccount(arg.keyName)
  const walletClient = createWalletClient({
    account: kmsAccount,
    chain: arg.chain,
    transport: arg.transport,
  });
  return walletClient
}
