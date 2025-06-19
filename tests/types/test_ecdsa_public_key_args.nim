discard """
  cmd: "nim c  --skipUserCfg $file"
"""

# nim c -r --skipUserCfg tests/types/test_ecdsa_public_key_args.nim

import unittest
import std/options
import std/sequtils
import std/strutils
import std/strformat
import std/tables
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/ic_record
import ../../src/nicp_cdk/ic_types/ic_principal
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode

# EcdsaCurve enum型定義（Motokoスタイル対応）
type
  EcdsaCurveTest* {.pure.} = enum
    secp256k1 = 0
    secp256r1 = 1

suite "ECDSA Public Key Args tests (Motoko Style)":
  
  test "Principal.bytes conversion test":
    # Principal → Blob変換のテスト（Motokoの仕様に従う）
    # 有効なPrincipal IDを使用（ガバナンスCanister）
    let testPrincipal = Principal.governanceCanister()
    let blobCaller = testPrincipal.bytes  # Principal.bytesを使用
    
    check blobCaller.len > 0
    check blobCaller.len <= 29  # Principalの最大長は29バイト
    echo "Principal bytes: ", blobCaller.mapIt(it.toHex(2)).join("")

  test "Management Canister Principal test":
    # Management CanisterのPrincipal("aaaaa-aa")での処理
    let managementPrincipal = Principal.managementCanister()
    let blobCaller = managementPrincipal.bytes
    
    # Management Canister ("aaaaa-aa") のバイト長は0が正常
    check blobCaller.len == 0  # Management Canisterは特別なPrincipalでバイト長0
    echo "Management Canister bytes (length 0 is normal): ", blobCaller.mapIt(it.toHex(2)).join("")

  test "derivation_path with caller blob":
    # callerのblobをderivation_pathに含める（Motokoスタイル）
    let testPrincipal = Principal.governanceCanister()
    let blobCaller = testPrincipal.bytes
    
    let derivationPath = @[blobCaller]
    let candidVec = newCandidValue(derivationPath)
    
    check candidVec.kind == ctVec
    check candidVec.vecVal.len == 1
    check candidVec.vecVal[0].kind == ctBlob
    check candidVec.vecVal[0].blobVal == blobCaller

  test "create basic ecdsa_public_key_args with explicit Record (Motoko style)":
    # Motokoリファレンス実装に基づいた構造（明示的なRecord作成）
    let testPrincipal = Principal.governanceCanister()
    let blobCaller = testPrincipal.bytes
    
    # key_idレコードを明示的に作成
    var keyIdFields = initTable[string, CandidValue]()
    keyIdFields["curve"] = newCandidValue(EcdsaCurveTest.secp256k1)
    keyIdFields["name"] = newCandidText("dfx_test_key")
    let keyIdRecord = newCandidRecord(keyIdFields)
    
    # ecdsa_argsレコードを明示的に作成
    var ecdsaFields = initTable[string, CandidValue]()
    ecdsaFields["canister_id"] = newCandidOpt(none(CandidValue))
    ecdsaFields["derivation_path"] = newCandidValue(@[blobCaller])
    ecdsaFields["key_id"] = keyIdRecord
    let ecdsaArgs = newCandidRecord(ecdsaFields)
    
    check ecdsaArgs.kind == ctRecord
    check ecdsaArgs.recordVal.fields.len == 3
    
    # canister_id field (opt canister_id) = null
    check ecdsaArgs.recordVal.fields.hasKey("canister_id")
    check ecdsaArgs.recordVal.fields["canister_id"].kind == ctOpt
    check not ecdsaArgs.recordVal.fields["canister_id"].optVal.isSome()
    
    # derivation_path field (vec blob) = [blobCaller]
    check ecdsaArgs.recordVal.fields.hasKey("derivation_path")
    check ecdsaArgs.recordVal.fields["derivation_path"].kind == ctVec
    check ecdsaArgs.recordVal.fields["derivation_path"].vecVal.len == 1
    check ecdsaArgs.recordVal.fields["derivation_path"].vecVal[0].kind == ctBlob
    check ecdsaArgs.recordVal.fields["derivation_path"].vecVal[0].blobVal == blobCaller
    
    # key_id field (record)
    check ecdsaArgs.recordVal.fields.hasKey("key_id")
    check ecdsaArgs.recordVal.fields["key_id"].kind == ctRecord

  test "enhanced %* macro functionality test":
    # 拡張された%*マクロの基本機能テスト
    let basicRecord = %*{
      "name": "test_ecdsa",
      "version": 1,
      "active": true
    }
    
    # 構造の検証
    check basicRecord.kind == ckRecord
    check basicRecord.fields.len == 3
    
    # 基本構造の検証
    check basicRecord.fields.hasKey("name")
    check basicRecord.fields.hasKey("version") 
    check basicRecord.fields.hasKey("active")
    
    # 型の検証
    check basicRecord.fields["name"].textVal == "test_ecdsa"
    check basicRecord.fields["version"].intVal == 1
    check basicRecord.fields["active"].boolVal == true

  test "key_id record structure (Motoko style)":
    # 明示的なkey_idレコード作成
    var keyIdFields = initTable[string, CandidValue]()
    keyIdFields["curve"] = newCandidValue(EcdsaCurveTest.secp256k1)
    keyIdFields["name"] = newCandidText("dfx_test_key")
    let keyId = newCandidRecord(keyIdFields)
    
    check keyId.kind == ctRecord
    check keyId.recordVal.fields.len == 2
    
    # curve field (variant)
    check keyId.recordVal.fields.hasKey("curve")
    check keyId.recordVal.fields["curve"].kind == ctVariant
    
    # name field (text)
    check keyId.recordVal.fields.hasKey("name")
    check keyId.recordVal.fields["name"].kind == ctText
    check keyId.recordVal.fields["name"].textVal == "dfx_test_key"

  test "ecdsa curve enum conversion":
    # EcdsaCurve enumのVariant変換テスト
    let curve1 = newCandidValue(EcdsaCurveTest.secp256k1)
    let curve2 = newCandidValue(EcdsaCurveTest.secp256r1)
    
    check curve1.kind == ctVariant
    check curve1.variantVal.tag == candidHash("secp256k1")
    
    check curve2.kind == ctVariant
    check curve2.variantVal.tag == candidHash("secp256r1")

  test "option principal handling (both None and Some)":
    # opt canister_id の None/Some パターンテスト
    let noneValue = none(Principal)
    let someValue = some(Principal.governanceCanister())
    
    let candidNone = newCandidValue(noneValue)
    let candidSome = newCandidValue(someValue)
    
    check candidNone.kind == ctOpt
    check not candidNone.optVal.isSome()
    
    check candidSome.kind == ctOpt
    check candidSome.optVal.isSome()

  test "encode and decode ecdsa args (Motoko style)":
    # Motokoリファレンス実装と互換性のあるエンコード・デコードテスト（明示的作成）
    let testPrincipal = Principal.governanceCanister()
    let blobCaller = testPrincipal.bytes
    
    # 明示的なRecord作成
    var keyIdFields = initTable[string, CandidValue]()
    keyIdFields["curve"] = newCandidValue(EcdsaCurveTest.secp256k1)
    keyIdFields["name"] = newCandidText("dfx_test_key")
    let keyIdRecord = newCandidRecord(keyIdFields)
    
    var ecdsaFields = initTable[string, CandidValue]()
    ecdsaFields["canister_id"] = newCandidOpt(none(CandidValue))
    ecdsaFields["derivation_path"] = newCandidValue(@[blobCaller])
    ecdsaFields["key_id"] = keyIdRecord
    let ecdsaArgs = newCandidRecord(ecdsaFields)
    
    echo "Original ECDSA args fields: ", ecdsaArgs.recordVal.fields.keys.toSeq()
    
    let encoded = encodeCandidMessage(@[ecdsaArgs])
    echo "Encoded message length: ", encoded.len
    
    let decoded = decodeCandidMessage(encoded)
    echo "Decoded values count: ", decoded.values.len
    
    check decoded.values.len == 1
    check decoded.values[0].kind == ctRecord
    
    # デコード後の構造確認
    let decodedRecord = decoded.values[0]
    echo "Decoded record type: ", decodedRecord.kind
    echo "Decoded record fields count: ", decodedRecord.recordVal.fields.len
    echo "Decoded record field keys: ", decodedRecord.recordVal.fields.keys.toSeq()
    
    # フィールド名のハッシュ値を計算して比較
    let canisterIdHash = $candidHash("canister_id")
    let derivationPathHash = $candidHash("derivation_path")
    let keyIdHash = $candidHash("key_id")
    
    echo "Expected canister_id hash: ", canisterIdHash
    echo "Expected derivation_path hash: ", derivationPathHash
    echo "Expected key_id hash: ", keyIdHash
    
    # フィールドの存在確認をハッシュ値で行う
    if decodedRecord.recordVal.fields.hasKey(canisterIdHash):
      echo "✅ canister_id field found (by hash)"
    else:
      echo "❌ canister_id field not found (by hash)"
    
    if decodedRecord.recordVal.fields.hasKey(derivationPathHash):
      echo "✅ derivation_path field found (by hash)"
    else:
      echo "❌ derivation_path field not found (by hash)"
      
    if decodedRecord.recordVal.fields.hasKey(keyIdHash):
      echo "✅ key_id field found (by hash)"
    else:
      echo "❌ key_id field not found (by hash)"
    
    # 実際のフィールド確認テストはハッシュ値で行う
    check decodedRecord.recordVal.fields.hasKey(canisterIdHash)
    check decodedRecord.recordVal.fields.hasKey(derivationPathHash)
    check decodedRecord.recordVal.fields.hasKey(keyIdHash)

  test "enhanced %* macro encode/decode test":
    # 拡張された%*マクロのエンコード・デコードテスト
    let basicRecord = %*{
      "message": "Hello ECDSA",
      "count": 42,
      "enabled": true
    }
    
    # CandidRecordからCandidValueに変換してエンコード
    let candidValue = newCandidValue(basicRecord)
    
    echo "Original basic record fields (%*): ", candidValue.recordVal.fields.keys.toSeq()
    
    let encoded = encodeCandidMessage(@[candidValue])
    echo "Encoded message length (%*): ", encoded.len
    
    let decoded = decodeCandidMessage(encoded)
    echo "Decoded values count (%*): ", decoded.values.len
    
    check decoded.values.len == 1
    check decoded.values[0].kind == ctRecord
    
    # デコード後の構造確認
    let decodedRecord = decoded.values[0]
    echo "Decoded record type (%*): ", decodedRecord.kind
    echo "Decoded record fields count (%*): ", decodedRecord.recordVal.fields.len
    check decodedRecord.recordVal.fields.len == 3

  test "nested records with %* macro":
    # ネストしたRecordの%*マクロテスト
    let nestedRecord = %*{
      "outer": {
        "inner": "nested_value",
        "number": 123
      },
      "simple": "simple_value"
    }
    
    # CandidRecordからCandidValueに変換してエンコード
    let candidValue = newCandidValue(nestedRecord)
    
    check candidValue.kind == ctRecord
    check candidValue.recordVal.fields.len == 2
    
    # ネストした構造の確認
    check candidValue.recordVal.fields.hasKey("outer")
    check candidValue.recordVal.fields.hasKey("simple")
    
    # エンコード・デコード往復テスト
    let encoded = encodeCandidMessage(@[candidValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctRecord

  test "simplified ECDSA structure with %* macro":
    # 簡単なECDSA構造の%*マクロテスト
    let testPrincipal = Principal.governanceCanister()
    let blobCaller = testPrincipal.bytes
    
    # key_idの部分を%*マクロで作成
    let keyIdRecord = %*{
      "curve": "secp256k1",
      "name": "dfx_test_key"
    }
    
    # メインのECDSA構造を%*マクロで作成（一部は明示的なCandidValue）
    let mainRecord = %*{
      "algorithm": "ECDSA",
      "version": 1
    }
    
    # 構造の検証
    check keyIdRecord.kind == ckRecord
    check keyIdRecord.fields.len == 2
    check keyIdRecord.fields.hasKey("curve")
    check keyIdRecord.fields.hasKey("name")
    
    check mainRecord.kind == ckRecord
    check mainRecord.fields.len == 2

  test "Management Canister style ecdsa args":
    # Management CanisterでのECDSA呼び出しスタイル（明示的作成）
    let managementPrincipal = Principal.managementCanister()
    let blobCaller = managementPrincipal.bytes
    
    var keyIdFields = initTable[string, CandidValue]()
    keyIdFields["curve"] = newCandidValue(EcdsaCurveTest.secp256k1)
    keyIdFields["name"] = newCandidText("dfx_test_key")
    let keyIdRecord = newCandidRecord(keyIdFields)
    
    var ecdsaFields = initTable[string, CandidValue]()
    ecdsaFields["canister_id"] = newCandidOpt(some(newCandidPrincipal(managementPrincipal)))
    ecdsaFields["derivation_path"] = newCandidValue(@[blobCaller])
    ecdsaFields["key_id"] = keyIdRecord
    let ecdsaArgs = newCandidRecord(ecdsaFields)
    
    check ecdsaArgs.kind == ctRecord
    check ecdsaArgs.recordVal.fields["canister_id"].optVal.isSome()
    check ecdsaArgs.recordVal.fields["canister_id"].optVal.get().principalVal.value == "aaaaa-aa"

  test "vec blob handling (multiple blobs)":
    # 複数のblobを含むderivation_pathのテスト
    let testPrincipal1 = Principal.governanceCanister()
    let testPrincipal2 = Principal.ledgerCanister()
    let blob1 = testPrincipal1.bytes
    let blob2 = testPrincipal2.bytes
    
    let derivationPath = @[blob1, blob2]
    let candidVec = newCandidValue(derivationPath)
    
    check candidVec.kind == ctVec
    check candidVec.vecVal.len == 2
    check candidVec.vecVal[0].kind == ctBlob
    check candidVec.vecVal[1].kind == ctBlob
    check candidVec.vecVal[0].blobVal == blob1
    check candidVec.vecVal[1].blobVal == blob2

  test "empty derivation_path":
    # 空のderivation_pathのテスト
    let derivationPath: seq[seq[uint8]] = @[]
    let candidVec = newCandidValue(derivationPath)
    
    check candidVec.kind == ctVec
    check candidVec.vecVal.len == 0

  test "both secp256k1 and secp256r1 curves":
    # 両方のカーブタイプのテスト（明示的作成）
    var keyIdFields1 = initTable[string, CandidValue]()
    keyIdFields1["curve"] = newCandidValue(EcdsaCurveTest.secp256k1)
    keyIdFields1["name"] = newCandidText("test_key_k1")
    let keyIdRecord1 = newCandidRecord(keyIdFields1)
    
    var keyIdFields2 = initTable[string, CandidValue]()
    keyIdFields2["curve"] = newCandidValue(EcdsaCurveTest.secp256r1)
    keyIdFields2["name"] = newCandidText("test_key_r1")
    let keyIdRecord2 = newCandidRecord(keyIdFields2)
    
    check keyIdRecord1.recordVal.fields["curve"].variantVal.tag == candidHash("secp256k1")
    check keyIdRecord2.recordVal.fields["curve"].variantVal.tag == candidHash("secp256r1")

  test "vec blob with seq[seq[uint8]] support":
    # 新しいseq[seq[uint8]]サポートのテスト
    let blob1 = @[0x74u8, 0x65u8, 0x73u8, 0x74u8]  # "test"
    let blob2 = @[0x64u8, 0x61u8, 0x74u8, 0x61u8]  # "data"
    let blobArray = @[blob1, blob2]
    
    let candidVec = newCandidValue(blobArray)
    
    check candidVec.kind == ctVec
    check candidVec.vecVal.len == 2
    check candidVec.vecVal[0].kind == ctBlob
    check candidVec.vecVal[0].blobVal == blob1
    check candidVec.vecVal[1].kind == ctBlob
    check candidVec.vecVal[1].blobVal == blob2

  test "ECDSA structure with new vec blob support":
    # seq[seq[uint8]]サポートを使用したECDSA構造作成
    let testPrincipal = Principal.managementCanister()
    let blobCaller = testPrincipal.bytes
    let derivationPath = @[blobCaller]
    
    # derivation_pathにseq[seq[uint8]]を直接使用
    let derivationPathValue = newCandidValue(derivationPath)
    
    check derivationPathValue.kind == ctVec
    check derivationPathValue.vecVal.len == 1
    check derivationPathValue.vecVal[0].kind == ctBlob
    check derivationPathValue.vecVal[0].blobVal == blobCaller
    
    # 完全なECDSA構造を作成
    var ecdsaFields = initTable[string, CandidValue]()
    ecdsaFields["canister_id"] = newCandidOpt(none(CandidValue))
    ecdsaFields["derivation_path"] = derivationPathValue
    
    var keyIdFields = initTable[string, CandidValue]()
    keyIdFields["curve"] = newCandidText("secp256k1")
    keyIdFields["name"] = newCandidText("dfx_test_key")
    let keyIdRecord = newCandidRecord(keyIdFields)
    ecdsaFields["key_id"] = keyIdRecord
    
    let ecdsaArgs = newCandidRecord(ecdsaFields)
    
    check ecdsaArgs.kind == ctRecord
    check ecdsaArgs.recordVal.fields.len == 3
    check ecdsaArgs.recordVal.fields.hasKey("derivation_path")
    check ecdsaArgs.recordVal.fields["derivation_path"].kind == ctVec 

  test "advanced %* macro with ECDSA-like structure":
    # より高度な%*マクロのテスト（ECDSA風構造）
    let testPrincipal = Principal.governanceCanister()
    let blobCaller = testPrincipal.bytes
    
    # %*マクロでネストした構造を作成（ECDSA風だが簡略化）
    let ecdsaLikeRecord = %*{
      "public_key_request": {
        "key_type": "ECDSA",
        "curve": "secp256k1",
        "derivation": "test_derivation"
      },
      "metadata": {
        "version": 1,
        "timestamp": 1234567890,
        "enabled": true
      },
      "security": {
        "level": "high",
        "auth_required": true
      }
    }
    
    # 構造の検証
    check ecdsaLikeRecord.kind == ckRecord
    check ecdsaLikeRecord.fields.len == 3
    
    # ネストした構造の確認
    check ecdsaLikeRecord.fields.hasKey("public_key_request")
    check ecdsaLikeRecord.fields.hasKey("metadata") 
    check ecdsaLikeRecord.fields.hasKey("security")
    
    # CandidValueに変換してエンコード・デコードテスト
    let candidValue = newCandidValue(ecdsaLikeRecord)
    let encoded = encodeCandidMessage(@[candidValue])
    let decoded = decodeCandidMessage(encoded)
    
    check decoded.values.len == 1
    check decoded.values[0].kind == ctRecord
    check decoded.values[0].recordVal.fields.len == 3

  test "%* macro with mixed value types":
    # %*マクロの混合データ型テスト
    let mixedRecord = %*{
      "text_field": "Hello World",
      "number_field": 42,
      "boolean_field": true,
      "float_field": 3.14,
      "nested_record": {
        "inner_text": "Inner Value",
        "inner_number": 100
      }
    }
    
    # 構造の検証
    check mixedRecord.kind == ckRecord
    check mixedRecord.fields.len == 5
    
    # 各フィールドの型検証
    check mixedRecord.fields.hasKey("text_field")
    check mixedRecord.fields.hasKey("number_field")
    check mixedRecord.fields.hasKey("boolean_field")
    check mixedRecord.fields.hasKey("float_field")
    check mixedRecord.fields.hasKey("nested_record")
    
    # 値の検証
    check mixedRecord.fields["text_field"].textVal == "Hello World"
    check mixedRecord.fields["number_field"].intVal == 42
    check mixedRecord.fields["boolean_field"].boolVal == true
    
    # エンコード・デコードテスト
    let candidValue = newCandidValue(mixedRecord)
    let encoded = encodeCandidMessage(@[candidValue])
    let decoded = decodeCandidMessage(encoded)
    
    check decoded.values.len == 1
    check decoded.values[0].kind == ctRecord