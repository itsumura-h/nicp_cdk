---
description: 49-add-wagmiブランチでの開発時に読み込む
alwaysApply: false
---
49-add-wagmi
===

このブランチで実装することは以下の通りです。
- /application/examples/t_ecdsaのフロントエンドにwagmiを追加
- Internet Identityでログインするとwindow.ethereumがブラウザにinjectされるようにicpAuth.tsを修正
- wagmiを経由してwalletClientのインスタンスを作成できるようにする
- EIP-1193仕様に準拠したEthereumプロバイダーの実装

## デバッグ用実行コマンド
```
cd /application/examples/t_ecdsa
npm run dev
```

## 進捗
- [x] wagmiライブラリの仕様と使用方法を調査
- [x] EIP-1193仕様とwindow.ethereumオブジェクトについて調査
- [x] ウォレットプロバイダーの実装方法を調査
- [x] icpAuth.tsを修正してwindow.ethereumをインジェクトする機能を追加
- [x] フロントエンドにwagmiを追加してwalletClientインスタンスを作成
- [x] 必要な依存関係をインストール (wagmi, @tanstack/react-query)
- [x] EIP-1193準拠のIcpEthereumProviderクラスを実装
- [x] useWagmiWalletフックを作成してwagmiとICP認証を統合
- [x] WagmiProviderとQueryClientProviderでアプリをラップ
- [x] WagmiDemoコンポーネントを追加して統合をテスト
- [x] index.tsxからwalletClientの定義を削除してWagmiDemoに集約
- [x] カスタムtransport設定でwindow.ethereumを使用
- [x] コントラクト操作をWagmiDemoに移動
- [x] IcpEthereumProviderにICPキャニスター呼び出しを統合
- [x] window.ethereum経由でICPキャニスターの署名・アドレス生成を実装
- [x] personal_sign, eth_requestAccounts等のメソッドでICP直接呼び出し
- [x] WagmiDemoにICP署名テスト機能を追加
- [x] 動作確認とテスト

## 参考資料
- Wagmi公式ドキュメント: https://wagmi.sh/
- EIP-1193仕様: https://eips.ethereum.org/EIPS/eip-1193
- Ethereum Provider API: https://docs.metamask.io/guide/ethereum-provider.html
- Internet Computer Identity: https://internetcomputer.org/docs/current/tokenomics/identity-auth/what-is-ic-identity

## 調査結果・設計まとめ

### Wagmiについて
- ReactベースのEthereumアプリケーション開発支援ライブラリ
- ウォレット接続、トランザクション管理、コントラクトとのやり取りを簡素化
- EIP-1193準拠のプロバイダーと統合可能
- createWalletClient関数でカスタムトランスポートを設定可能

### EIP-1193について  
- Ethereumプロバイダーの標準インターフェース定義
- DAppとウォレット間の通信を統一
- window.ethereumオブジェクトを通じてウォレットとやり取り
- request、on、removeListenerメソッドを提供

### 実装方針
1. Internet Identity認証成功後にwindow.ethereumオブジェクトを作成・注入
2. EIP-1193仕様に準拠したプロバイダーインターフェースを実装
3. ICPのt_ECDSA機能を使用してEthereumトランザクションに署名
4. wagmiのcreateWalletClientでカスタムトランスポートとして設定

### 実装内容
- **IcpEthereumProvider**: EIP-1193準拠のEthereumプロバイダークラス
  - `request()`: eth_requestAccounts, personal_sign, eth_sendTransactionなどのメソッドをサポート
  - イベントリスナー機能 (on, removeListener, emit)
  - **ICPキャニスター直接統合**: AuthClientとBackendActorを内蔵
  - **署名機能**: `signWithIcp()`でICPキャニスターの`signWithEvmWallet()`を直接呼び出し
  - **アドレス生成**: `getIcpAddress()`でICPキャニスターの`getEvmAddress()`を直接呼び出し
  - **公開鍵管理**: `ensurePublicKey()`で自動的に公開鍵を生成・取得
- **useWagmiWallet**: wagmiとICP認証を統合するカスタムフック
  - ICP認証とwagmi接続の両方を管理
  - 自動的な接続フロー
- **WagmiDemo**: 統合テスト用コンポーネント
  - ICP認証とwagmi接続のデモ
  - アドレス一致確認機能
  - カスタムwalletClientの管理（window.ethereumを使用）
  - **ICP署名テスト**: window.ethereum.request()経由でICPキャニスター署名をテスト
  - コントラクト操作（Counter読み取り・書き込み）
- **wagmiConfig**: カスタムtransport設定
  - window.ethereumが利用可能な場合はcustom()を使用
  - フォールバックとしてhttp()を使用
