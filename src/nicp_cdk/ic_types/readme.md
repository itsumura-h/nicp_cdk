IC Types
===

ICPで扱う型を保持する。

**ic0はimportしない**

https://github.com/dfinity/agent-js/blob/main/packages/candid/src/idl.ts


## 型変換の流れ
- ICP (バイト列のcandid message)
- CandidDecodeResult (デコード結果をテーブル形式の型とそれ以外の型に分けて保持する)


## 目指すアーキテクチャ
- ic_XX
  - ICP固有の型の定義する
    - Principal
    - Record
    - Variant
    - Func
    - Service
    - ...etc
  - candid_typesで定義されている、ICP固有の型の関数を定義する
  - 各型毎に1つのファイルに実装する
  - 他のファイルに依存しない
- candid_types
  - candid messageの規格に則り、encode、decodeをする時に使うCandidValueの型定義をする
  - recordとvariantなど、子要素としてCandidValueを持つ型は循環参照を防ぐためにここで定義する
  - それ以外の型はic_XXの方で定義する
- candid_funcs
  - candid_typesで定義された型に関する関数を定義する
  - ic_XXに依存する
  - ic_XXに定義されている型をCandidValueに変換する関数を定義する
- ic_record
  - NimのJsonNodeを参考にしたCandidRecord型の型定義と関数を定義する


## リファクタリング計画

### 現在の課題
- [x] `ic_record.nim`が828行で肥大化している
- [x] 型定義が`candid_types.nim`と`ic_record.nim`で重複している
- [x] `ic_*.nim`ファイルが`candid_types.nim`に依存している
- [x] 変換ロジックが分散している

### Phase 1: ic_XXファイルの独立化 🔄
**目標**: 各`ic_*.nim`ファイルから`candid_types.nim`への依存を除去

- [x] `ic_principal.nim`の独立化
  - [x] `candid_types.nim`への依存を除去
  - [x] 必要最小限の型定義のみに絞る
  - [x] テスト作成完了
- [x] `ic_text.nim`の独立化
  - [x] テスト作成完了
- [x] `ic_bool.nim`の独立化
  - [x] テスト作成完了
- [x] `ic_int.nim`の独立化
  - [x] テスト作成完了
- [x] `ic_float.nim`の独立化
  - [x] テスト作成完了
- [ ] `ic_variant.nim`の独立化（関数重複問題あり）
- [ ] `ic_service.nim`の独立化（ic_recordに依存）
- [x] `ic_empty.nim`の独立化
  - [x] テスト作成完了

### Phase 2: candid_funcs.nimの作成 ✅
**目標**: 型変換関数を集約し、依存関係を整理

- [x] `candid_funcs.nim`ファイルを作成
  - [x] 基本型変換関数の実装
  - [x] テスト作成完了
- [x] `ic_*`型から`CandidValue`への変換関数を移動
  - [x] 基本型（bool, string, int, uint, float, Principal, blob）の変換関数
  - [x] 型判定ヘルパー関数
- [x] `ic_record.nim`の変換ロジックを`candid_funcs.nim`に移動
  - [x] `fromCandidValue`関数の移動
  - [x] `toCandidValue`関数の移動
- [x] 重複する変換関数の統合
- [x] 関数重複問題の解決（`getEnum`関数）
  - [x] 新しい名前で統合：`getEnumFromVariant`
  - [x] Variant関連関数の統合完了
  - [x] テスト作成完了

### Phase 3: ic_record.nimの簡素化 ✅
**目標**: `ic_record.nim`を`CandidRecord`の補助関数のみに特化

- [x] 重複する型変換ロジックの削除
- [x] `fromCandidValue`/`toCandidValue`の`candid_funcs.nim`への移動
- [x] `CandidRecord`固有の操作のみに集約
- [x] ファイルサイズの大幅削減（828行→429行、約48%削減）

### Phase 4: テストとドキュメント更新 ⏳
**目標**: リファクタリング後の品質保証

- [ ] 全テストの実行と修正
- [ ] 新しい依存関係のドキュメント化
- [ ] 使用例の更新
- [ ] パフォーマンステスト

### 進捗状況
- **Phase 1**: ✅ 完了 (基本型の独立化完了)
- **Phase 2**: ✅ 完了 (candid_funcs.nim作成・変換関数集約・重複問題解決)
- **Phase 3**: ✅ 完了 (ic_record.nim簡素化・型変換ロジック分離)  
- **Phase 4**: ⏳ 待機中

### 解決済み問題
1. ✅ **関数重複問題**: `candid_funcs.nim`で統合済み（`getEnumFromVariant`等の新名称）
2. ✅ **循環依存**: `ic_variant.nim`、`ic_service.nim`が`candid_funcs.nim`に依存するよう変更
3. ✅ **巨大ファイル**: `ic_record.nim`が828行→429行に約48%削減

### 次のアクション
- [x] ✅ 関数重複問題の解決（関数名の修正またはネームスペース分離）
- [x] ✅ `ic_service.nim`の簡素化（`ic_record.nim`依存の除去）
- [x] ✅ Phase 3完了: `ic_record.nim`の簡素化とCandidRecord固有操作への特化
- [ ] Phase 4実行: 全テストの実行と品質保証

### 注意事項
- 既存のテストが全て通るよう、インターフェースの後方互換性を保つ
- 段階的に実行し、各フェーズ完了後に動作確認を行う
- `candid_types.nim`での循環参照対策は現状維持する
