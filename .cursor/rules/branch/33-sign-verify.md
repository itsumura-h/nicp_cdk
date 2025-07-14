33-sign-verify
===

このブランチで実装することは以下の通りです。
- ICPのECDSA署名・検証機能の実装とテスト
- Management CanisterのECDSA APIを使用したデジタル署名システム
- 公開鍵生成、署名、検証の完全なワークフロー実装

## 進捗
- [x] ECDSA署名・検証用のコードベース調査
- [x] signWithEcdsa関数のIC0406エラーのデバッグと修正
- [x] 適切なローカル開発環境の設定確立
- [x] 全てのECDSA関数の動作確認完了

## 参考資料
- Internet Computer ECDSA API: https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-ecdsa_public_key
- Management Canister仕様: https://internetcomputer.org/docs/current/references/ic-interface-spec/#the-ic-management-canister
- 実装コード: examples/t_ecdsa/src/t_ecdsa_backend/
- ECDSA実装: src/nicp_cdk/algorithm/ecdsa.nim

## 調査結果・設計まとめ

### IC0406エラーの原因と解決方法

#### **問題の特定**
ICPローカル環境でECDSA署名機能を使用する際に発生したIC0406エラーは、Management CanisterからのECDSA要求拒否を示していました。

#### **根本原因**
1. **canister_id設定の誤り**: `EcdsaPublicKeyArgs`および`EcdsaSignArgs`で間違ったプリンシパルを指定
2. **ローカル環境設定不備**: dfx.jsonにECDSA機能を有効にするネットワーク設定が不足
3. **環境の不整合**: 適切な再起動プロセスが実行されていない

### **正しい実装パターン**

#### 1. ECDSA引数の適切な設定
```nim
// ❌ 間違った設定（IC0406エラーの原因）
let arg = EcdsaPublicKeyArgs(
  canister_id: Principal.fromText("lz3um-vp777-77777-aaaba-cai").some(),
  derivation_path: @[caller.bytes],
  key_id: EcdsaKeyId(
    curve: EcdsaCurve.secp256k1,
    name: "dfx_test_key"
  )
)

// ✅ 正しい設定
let arg = EcdsaPublicKeyArgs(
  canister_id: none(Principal),  // ローカル環境ではNoneが必須
  derivation_path: @[caller.bytes],
  key_id: EcdsaKeyId(
    curve: EcdsaCurve.secp256k1,
    name: "dfx_test_key"
  )
)
```

#### 2. dfx.json設定
```json
{
  "canisters": { /* ... */ },
  "networks": {
    "local": {
      "bind": "0.0.0.0:4943",
      "type": "ephemeral",
      "replica": {
        "subnet_type": "system"  // ECDSA機能に必要
      }
    }
  }
}
```

#### 3. 適切な環境再起動プロセス
```bash
# ❌ 間違った方法
dfx stop
dfx start --clean --background

# ✅ 正しい方法（プロジェクト固有）
cd /application
./run.sh
```

### **動作確認済み機能**

#### 完全なECDSAワークフロー
1. **公開鍵生成** (`getNewPublicKey`): ✅
2. **ECDSA署名** (`signWithEcdsa`): ✅
3. **署名検証** (`verifyWithEcdsa`): ✅
4. **既存公開鍵取得** (`getPublicKey`): ✅
5. **EVMアドレス生成** (`getEvmAddress`): ✅

#### テスト結果
```bash
# 署名生成成功例
dfx canister call t_ecdsa_backend signWithEcdsa "hello world"
# → 64バイト署名ハッシュ生成 + 内部検証成功

# 署名検証成功例
dfx canister call t_ecdsa_backend verifyWithEcdsa '(record { 
  message = "hello world"; 
  signature = "2E845598..."; 
  publicKey = "03E6502F..." 
})'
# → true（検証成功）
```

### **重要な学習ポイント**

#### ICPローカル開発環境でのECDSA利用
1. **canister_id**: ローカル環境では必ず`none(Principal)`を使用
2. **subnet_type**: "system"設定でECDSA機能を有効化
3. **再起動**: プロジェクト固有の`./run.sh`スクリプトを使用

#### エラーデバッグのアプローチ
1. **エラーコード解析**: IC0406 = Management Canister拒否
2. **設定の段階的確認**: 引数 → ネットワーク設定 → 環境再起動
3. **機能別テスト**: 公開鍵生成 → 署名 → 検証の順で確認

#### セキュリティ考慮事項
- derivation_pathにcaller.bytesを使用することで、呼び出し元ごとに異なる鍵ペアを生成
- 署名前のメッセージハッシュ化（SHA256）で一貫性を保証
- 公開鍵の一意性により、署名検証の信頼性を確保

この知見により、ICPでのECDSA機能を安全かつ効率的に利用できるようになりました。 