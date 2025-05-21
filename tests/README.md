# async_wasmライブラリのテスト

このディレクトリには、async_wasmライブラリのテストが含まれています。テストはwasmerやwamstimeなどの純粋なWASMランタイムで実行されます。

## テストファイル

- `test_async.nim` - 非同期処理の基本機能テスト
- `test_async.nims` - WebAssembly向けのテスト設定
- `wasmasyncruntests.nim` - WASMランタイムでテストを実行するためのヘルパースクリプト

## テスト実行方法

### 通常のNim環境でのテスト（簡易テスト）

以下のコマンドで、通常のNim環境でテストを実行します：

```bash
nim c -r tests/test_async.nim
```

### WASMランタイム環境でのテスト（本格的なテスト）

WebAssemblyランタイム環境でテストを実行するには、以下の手順に従います：

1. 前提条件：以下のいずれかのWASMランタイムがインストールされていること
   - wasmer
   - wasmtime
   - wasm3
   - iwasm (WAMR)

2. テスト実行コマンド:

```bash
nim c -r tests/wasmasyncruntests.nim
```

このコマンドは以下の処理を実行します：
- test_async.nimをWASMバイナリにコンパイル
- インストールされているWASMランタイムを自動検出
- コンパイルしたWASMバイナリをランタイムで実行
- テスト結果を表示

## テスト内容

### 基本的な非同期機能テスト

- Futureの基本操作 - Futureの作成、完了、値の取得
- コールバック機能 - Futureにコールバックを追加し、呼び出されることを確認

### 非同期関数テスト

- 基本的な非同期関数 - シンプルな非同期関数の実行と戻り値の確認
- 遅延のある非同期関数 - sleepAsyncを使った遅延を含む関数
- 連鎖した非同期関数 - 複数の非同期関数を連携させる

### FutureStreamテスト

- ストリーム操作 - FutureStreamへの書き込みと読み取り

### WASM固有テスト

- WASM環境での非同期処理 - WebAssembly環境での非同期処理
- 複数の非同期処理の同時実行 - 並行処理のテスト

## テスト実行の仕組み

テストの実行は以下の仕組みで動作します：

1. `wasmasyncruntests.nim`がtest_async.nimをWASMバイナリにコンパイル
2. 利用可能なWASMランタイム(wasmer/wasmtime/wasm3/iwasm)を検出
3. コンパイルされたWASMバイナリをランタイムで実行
4. 標準出力にテスト結果が表示される
5. テスト失敗数に応じた終了コードが返される

## 設定ファイル

`test_async.nims`は、WebAssembly向けのコンパイル設定を行います。主な設定内容：

- WebAssembly用のコンパイラ設定
- メモリ管理設定（ORC）
- サイズ最適化設定
- WASIランタイム用の設定

これらの設定は、`examples/t_ecdsa/src/t_ecdsa_backend/config.nims`を参考に作成されています。 
