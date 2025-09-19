EIP‑1193 準拠の window.ethereum を ICP キャニスター署名で実装する
===

目的
---
ICP の tECDSA を「署名機」として使い、フロントエンドでは EIP‑1193 準拠 Provider（`window.ethereum`）を提供して任意の dApp/ライブラリ（例: Viem, ethers）から透過的に利用できるようにする。読み取り系 RPC は既存の Ethereum ノード/プロバイダ（Alchemy/Infura/Anvil など）に委譲し、アカウント/署名のみを ICP が担う二層構成を採る。

要約（TL;DR）
---
- 署名/アカウント系メソッドは ICP キャニスターに委譲、ネットワーク系は外部 RPC へフォワード
- `eth_requestAccounts`/`eth_accounts`/`personal_sign` は最小実装で動作可能
- `eth_sendTransaction` は「TSで序列化→ハッシュ→ICP で署名→rawTx 組み立て→`eth_sendRawTransaction`」で実現
- EIP‑712（`eth_signTypedData*`）と `eth_sign` はバックエンド拡張で対応予定

アーキテクチャ
---
- 署名/アカウント: ICP キャニスター（tECDSA）
  - 公開鍵の確保: `getPublicKey()` 不在時は `getNewPublicKey()`
  - アドレス解決: `getEvmAddress()`（secp256k1 公開鍵 → Ethereum アドレス）
  - メッセージ署名: `signWithEthereum(message)`（EIP‑191）
  - 取引ハッシュ署名（提案）: `signTxHashWithEthereum(hashHex)` → 0x + r(32) + s(32) + v(1)
- ネットワーク/RPC: 任意の Ethereum JSON‑RPC エンドポイント
- Provider（フロント）: EIP‑1193 の `request({ method, params })` を実装し、上記の委譲先に振り分け

EIP‑1193 メソッド委譲方針
---
- アカウント/署名系（ICP に委譲）
  - `eth_requestAccounts`: 認証（Internet Identity）→ 公開鍵確保 → EVM アドレス解決 → `accountsChanged`/`connect`
  - `eth_accounts`: キャッシュ済みアカウントを返却（未設定なら空）
  - `personal_sign`: 文字列メッセージを正規化し `signWithEthereum` を呼ぶ
  - `eth_sign`: 未対応（要: 任意 32byte 署名 API）
  - `eth_signTypedData*`: 未対応（要: EIP‑712 ハッシュ生成 + 署名 API）
  - `eth_sendTransaction`: 取引を序列化→keccak256→`signTxHashWithEthereum`→rawTx 組み立て→`eth_sendRawTransaction`
- ネットワーク系（RPC にフォワード）
  - 例: `eth_chainId`, `eth_call`, `eth_estimateGas`, `eth_getBalance`, `eth_feeHistory` など
- チェーン切替/イベント
  - `wallet_switchEthereumChain`: `chainId` と RPC URL を切替、`chainChanged` を発火
  - `accountsChanged`, `connect`, `disconnect`, `message`: Provider 内で適切に発火

バックエンド（キャニスター）API 仕様
---
- 既存
  - `getPublicKey()`: 既存鍵の取得。未存在時は例外
  - `getNewPublicKey()`: 新規鍵を生成
  - `getEvmAddress()`: EVM アドレス（`0x…`）
  - `signWithEthereum(message: text) -> text`: EIP‑191 準拠で署名（返り値: `0x…`）
- 追加（提案）
  - `signTxHashWithEthereum(hashHex: text) -> text`
    - 入力: `0x` + 32byte ハッシュ
    - 出力: `0x` + r(32) + s(32) + v(1)（65 byte、Ethereum 署名）
    - 手順: Management Canister で (r,s) 取得 → recovery id を計算 → 65byte 署名を返却
  - （将来）`signTypedData(typedDataJson: text) -> text`
    - サーバ側で EIP‑712 の構造体ハッシュ（domainSeparator, messageHash）を生成して署名

フロントエンド実装方針（Provider）
---
- `IcpEthereumProvider` クラスを実装し、以下を提供
  - `request({ method, params })`: メソッドで分岐し、ICP or RPC に委譲
  - `on(event, listener)`, `removeListener(event, listener)`: EIP‑1193 イベント
  - `installOnWindow()`: 初期化時に `window.ethereum` に自身を注入し `ethereum#initialized` を dispatch
  - 識別子: `isIcpCanisterWallet = true` を公開（UX/分岐用）
- メッセージ正規化
  - dApp は `personal_sign` に Hex 文字列を渡すことが多い → Hex → UTF‑8 変換、またはバックエンドを Hex そのままに対応させる
- 署名形式
  - 返却は r,s,v（65 byte）。Typed Tx（EIP‑1559）では yParity と互換（Viem が吸収）
- `eth_sendTransaction` の詳細
  1) `estimateGas`/`getGasPrice`/`getFeeHistory`/`getTransactionCount` などでフィールドを補完
  2) `serializeTransaction(unsigned)` でプレ序列化 → `keccak256` でハッシュ
  3) `signTxHashWithEthereum` に渡して r,s,v を取得
  4) `serializeTransaction(unsigned, signature)` で rawTx 化 → `eth_sendRawTransaction`

エラーハンドリング/互換性
---
- 署名機能が未解放の場合の再試行（`getNewPublicKey` → `getEvmAddress`）
- `personal_sign` の Hex 入力未対応 → バックエンド拡張を推奨
- `ProviderRpcError` 互換のエラーコード化は将来対応（必要に応じて）
- `wallet_switchEthereumChain` 時は RPC URL も同時に切替（設定管理を統一）

セキュリティ
---
- `eth_requestAccounts` 時に Internet Identity による認可
- ドメイン/オリジン境界での許可管理（サイトごとのアカウント公開/拒否）
- 署名対象の明示（EIP‑191 prefix、EIP‑712 のダイジェスト表示）

テスト計画
---
- ローカル: Anvil（`http://localhost:8545`）+ dfx ローカル + tECDSA
- TS 統合テスト
  - Counter.sol の `setNumber`/`increment` を実行→状態 read で検証
  - Viem クライアントで読み取り系 RPC を検証、署名はキャニスター経由
- Nim ハーネス（将来）
  - Anvil/dfx 起動 → TS テストを外部プロセスで実行 → 成否検証

導入手順（最小）
---
1. フロントで Internet Identity にログイン
2. `IcpEthereumProvider` を初期化し `window.ethereum` に注入
3. dApp からは通常通り `window.ethereum` を利用

既知の制限と TODO
---
- `personal_sign` の Hex 入力（0x…）をバックエンドで直接サポート
- `eth_sign`（任意 32byte 署名）API の追加
- EIP‑712（`eth_signTypedData*`）API の追加
- 実ネットワーク複数チェーンの切替と RPC 管理

関連ファイル/参考
---
- 既存実装: `examples/t_ecdsa/src/t_ecdsa_frontend/src/hooks/icpWalletClient.ts`
- ブランチルール: `/application/.cursor/rules/branch/38-ethereum-send-transaction.mdc`
- 参考リンク
  - [Viem: Custom Accounts / Wallets](https://viem.sh/docs/accounts/custom)
  - [IC Management Canister: ECDSA](https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-ecdsa_public_key)


