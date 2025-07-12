# ECDSA 公開鍵・署名・検証総覧

このドキュメントでは、ICP および Ethereum における ECDSA 公開鍵形式、署名形式、および検証フローをまとめ、それぞれの Nim モジュール（`ecdsa.nim`、`ethereum.nim`）の実装例を示します。

---

## 1. 公開鍵形式

### 1.1 圧縮形式 (Compressed Form)
- バイト長: 33 バイト
- 先頭バイト: `0x02` または `0x03` (Y 座標の偶奇情報)
- hex 表記: 66 文字

### 1.2 非圧縮形式 (Uncompressed Form)
- バイト長: 65 バイト
- 先頭バイト: `0x04`
- hex 表記: 130 文字

Y 座標は以下の式で復元:
```text
Y^2 ≡ X^3 + aX + b  (mod p)
// secp256k1: a = 0, b = 7
```

---

## 2. 署名形式

### 2.1 Raw (Compact) 形式
- r (32 バイト) ∥ s (32 バイト) の 64 バイト
- hex 表記: 128 文字

### 2.2 DER 形式 (ASN.1)
- `0x30` で始まる SEQUENCE
- 可変長エンコーディングによる `INTEGER(r)`, `INTEGER(s)`

### 2.3 Ethereum 形式
- r (32 バイト) ∥ s (32 バイト) ∥ v (1 バイト) の 65 バイト
- hex 表記: 130 文字（0xなし）、0xプレフィックス付きで 132 文字

### 2.4 ICP Management Canister 形式
- **確認済み**: Raw (Compact) 形式 - r (32 バイト) ∥ s (32 バイト) の 64 バイト
- hex 表記: 128 文字
- DER形式ではなく、Raw形式で署名を返す

#### 実証実験結果（2025-07-12）
ICPマネジメントキャニスターの`sign_with_ecdsa`メソッドの返り値形式を実際に検証：

**テスト実行**:
```bash
dfx canister call t_ecdsa_backend signWithEcdsa "hello world"
dfx canister call t_ecdsa_backend signWithEcdsa "test message"
```

**結果**:
- **署名長**: 64バイト（128文字hex）確認
- **形式**: Raw形式（r||s, 32+32バイト）確認
- **DER形式ではない**: 先頭バイトが0x30ではなく、固定64バイト長

**署名例**:
1. メッセージ「hello world」:
   - 署名: `2E845598247622D38C6FAF1CCAD0A91CA3554AA0F81AF50BA9CFC09A5F12999A6CA4D32FC9DFF51CA88F4B5E4742BA6E565973B904E7B6516A9523CA4561019A`
   - 長さ: 64バイト
   - 先頭バイト: 0x2E

2. メッセージ「test message」:
   - 署名: `969397D018F951F999EB791229ED7B7EF6958C5D20E64DD83CE6308433C341E317D52C7F7C76B224F8D78560E08DB3E87D67D08888C2DFAEE741B326413083D6`
   - 長さ: 64バイト
   - 先頭バイト: 0x96

**結論**: ICPマネジメントキャニスターは確実にRaw形式（非DER形式）でECDSA署名を返す。

---

## 3. 検証フロー

### 3.1 汎用 ECDSA 検証 (ICP)
1. hex → バイト列に変換 (`hexToBytes`)
2. 公開鍵形式判定: 長さと先頭バイトで 圧縮/非圧縮 を判別、必要なら Y を復元
3. 署名解析: 長さや先頭バイトで Raw/DER 判定、DER はデコードで r,s を抽出
4. s の正規化 (Low-S enforcement)
5. メッセージハッシュ計算: 生の Keccak-256 → 32 バイトハッシュ
6. ECDSA 検証: `verifyEcdsaSignature(msgHash, signatureBytes, pubKeyBytes)` → bool

### 3.2 Ethereum 署名検証
1. メッセージを EIP-191 形式で整形し Keccak-256 ハッシュ (`keccak256Hash`)
2. `parseSignature` で r,s,v を抽出
3. `recoverPublicKeyFromSignature(messageHash, signatureHex, recoveryId)` で公開鍵復元 (recoveryId=0,1)
4. `publicKeyToEthereumAddress(pubKey)` でアドレス生成 → 入力アドレスと比較

---

## 4. モジュール別実装

### 4.1 ecdsa.nim
```nim
proc verifyEcdsaSignature*(
  messageHash: seq[uint8],
  signature: seq[uint8],
  publicKey: seq[uint8]
): bool

proc hexToBytes*(hexStr: string): seq[uint8]
proc parseSignature*(signatureBytes: seq[uint8]): tuple[r: seq[uint8], s: seq[uint8]]
```

#### フォーマット
- 公開鍵: `seq[uint8]` 圧縮形式 33 バイト (66 文字 hex)
- 署名: `seq[uint8]` DER 形式 (ASN.1 SEQUENCE) - ICPマネジメントキャニスターから返される

#### 検証フロー
1. `hexToBytes` でバイト列に変換
2. Raw形式署名の解析: 64バイトの r||s 形式として処理
3. `verifyEcdsaSignature` に msgHash, Raw 署名バイト列, 圧縮形式公開鍵を渡して検証

### 4.2 ethereum.nim
```nim
proc verifyEthereumSignatureWithAddress*(
  ethereumAddress: string,
  message: string,
  signatureHex: string
): bool

proc recoverPublicKeyFromSignature*(
  messageHash: seq[uint8],
  signatureHex: string,
  recoveryId: uint8
): seq[uint8]

proc publicKeyToEthereumAddress*(pubKey: seq[uint8]): string

proc keccak256Hash*(data: string): seq[uint8]
proc hexToBytes*(hexStr: string): seq[uint8]
proc parseSignature*(signatureHex: string): tuple[r: seq[uint8], s: seq[uint8], v: uint8]
```

#### フォーマット
- アドレス: `string` (`0x`+40文字 hex)
- 署名: `string` Raw 形式 r(32バイト)+s(32バイト)+v(1バイト) の 65バイト (130文字 hex, 0x付き132文字)

#### 検証フロー
1. `keccak256Hash` で EIP-191 形式のハッシュ生成
2. `parseSignature` で r,s,v を抽出
3. 各 recoveryId(0,1) で `recoverPublicKeyFromSignature` → pubKeyBytes
4. `publicKeyToEthereumAddress` で生成されたアドレスと照合

---

## 5. 使用例

### 5.1 汎用 ECDSA 検証 (ICP)
```nim
let messageHash = keccak256HashRaw(message)
let sigBytes = hexToBytes(sigHex)  # Raw形式の署名（64バイト）
let pubKeyBytes = hexToBytes(pubKeyHex)  # 圧縮形式の公開鍵
let ok = verifyEcdsaSignature(messageHash, sigBytes, pubKeyBytes)
echo "Signature valid: ", ok
```

### 5.2 Ethereum 署名検証
```nim
let address = "0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6"
let message = "Hello, World!"
let signature = "0x1234..."
let valid = verifyEthereumSignatureWithAddress(address, message, signature)
echo "Ethereum signature valid: ", valid
```

---

## 6. Ethereum アドレス導出
1. 圧縮形式公開鍵(33バイト) → 非圧縮形式(65バイト) に展開 (`decompressPublicKey`)
2. 先頭バイト `0x04` を除去 → 64バイト座標データ
3. `keccak256Hash` でハッシュ化
4. ハッシュ結果の下位 20バイト → `0x` プレフィックス付き hex 文字列

---

## 7. 参考資料
- [libsecp256k1 ドキュメント](https://github.com/bitcoin-core/secp256k1)
- [EIP-191: Signed Data Standard](https://eips.ethereum.org/EIPS/eip-191)
- [EIP-712: Typed Structured Data](https://eips.ethereum.org/EIPS/eip-712) 

---

実行コマンド
```
cd /application/examples/t_ecdsa
dfx deploy -y
dfx canister call t_ecdsa_backend getNewPublicKey
dfx canister call t_ecdsa_backend getPublicKey
dfx canister call t_ecdsa_backend signWithEcdsa "hello world"
dfx canister call t_ecdsa_backend verifyWithEcdsa
```
verifyWithEcdsaへ与える引数は自分で考えて