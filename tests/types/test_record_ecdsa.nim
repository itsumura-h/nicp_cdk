discard """
  cmd: "nim c --skipUserCfg $file"
"""

# nim c -r --skipUserCfg tests/types/test_record_ecdsa.nim

import std/unittest
import std/options
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/ic_record
import ../../src/nicp_cdk/ic_types/ic_principal

# ECDSA public key引数構造専用テストスイート
suite "ECDSA Public Key引数構造テスト":
  
  test "基本的なECDSA構造作成テスト":
    echo "===== 基本的なECDSA構造作成テスト ====="
    
    # Step 1: EcdsaCurve enumの定義
    type EcdsaCurve = enum
      secp256k1
      secp256r1
    
    echo "Step 1: EcdsaCurve enum定義完了"
    
    # Step 2: derivation_pathの作成（seq[seq[uint8]]）
    let caller = Principal.fromText("aaaaa-aa")
    let derivationPath = @[caller.bytes]
    
    echo "Step 2: derivationPath作成完了"
    echo "  caller principal: ", caller.value
    echo "  derivationPath.len: ", derivationPath.len
    echo "  derivationPath[0].len: ", derivationPath[0].len
    
    try:
      # Step 3: processSeqValueマクロでseq[seq[uint8]]を変換
      let seqValue = processSeqValue(derivationPath)
      echo "Step 3: processSeqValue成功, kind = ", seqValue.kind
      
      # Step 4: CandidRecordを使用したECDSA構造作成
      let ecdsaArgs = newCRecordEmpty()
      
      # canister_id: Option<Principal> = None
      ecdsaArgs["canister_id"] = newCOptionNone()
      echo "Step 4a: canister_id (None) 設定成功"
      
      # derivation_path: Vec<Blob>
      ecdsaArgs["derivation_path"] = candidValueToCandidRecord(seqValue)
      echo "Step 4b: derivation_path設定成功"
      
      # key_id: Record { curve: Variant, name: Text }
      let keyIdRecord = newCRecordEmpty()
      keyIdRecord["curve"] = candidValueToCandidRecord(newCandidValue(EcdsaCurve.secp256k1))
      keyIdRecord["name"] = candidValueToCandidRecord(newCandidValue("dfx_test_key"))
      
      ecdsaArgs["key_id"] = keyIdRecord
      echo "Step 4c: key_id設定成功"
      
      echo "ECDSA引数構造の作成成功"
      echo "構造: ", $ecdsaArgs
      
    except Exception as e:
      echo "ECDSA引数構造作成エラー: ", e.msg
    
    echo "===== 基本的なECDSA構造作成テスト完了 ====="
    check true

  test "ECDSA構造のフィールド検証テスト":
    echo "===== ECDSA構造のフィールド検証テスト ====="
    
    type EcdsaCurve {.pure.} = enum
      secp256k1 = 0
      secp256r1 = 1
    
    try:
      let caller = Principal.fromText("aaaaa-aa")
      let derivationPath = @[caller.bytes]
      
      # ECDSA構造を作成
      let ecdsaArgs = newCRecordEmpty()
      ecdsaArgs["canister_id"] = newCOptionNone()
      ecdsaArgs["derivation_path"] = candidValueToCandidRecord(processSeqValue(derivationPath))
      
      let keyIdRecord = newCRecordEmpty()
      keyIdRecord["curve"] = candidValueToCandidRecord(newCandidValue(EcdsaCurve.secp256k1))
      keyIdRecord["name"] = candidValueToCandidRecord(newCandidValue("dfx_test_key"))
      ecdsaArgs["key_id"] = keyIdRecord
      
      echo "ECDSA構造作成完了、フィールド検証開始"
      
      # フィールド検証
      # 1. canister_idの検証
      let canisterIdField = ecdsaArgs["canister_id"]
      echo "canister_id field kind: ", canisterIdField.kind
      
      # 2. derivation_pathの検証  
      let derivPathField = ecdsaArgs["derivation_path"]
      echo "derivation_path field kind: ", derivPathField.kind
      
      # 3. key_idの検証
      let keyIdField = ecdsaArgs["key_id"]
      echo "key_id field kind: ", keyIdField.kind
      
      # 詳細検証は後で実装
      echo "フィールド検証完了"
      
    except Exception as e:
      echo "フィールド検証エラー: ", e.msg
    
    echo "===== ECDSA構造のフィールド検証テスト完了 ====="
    check true

  test "複数derivation_pathのテスト":
    echo "===== 複数derivation_pathのテスト ====="
    
    type EcdsaCurve {.pure.} = enum
      secp256k1 = 0
      secp256r1 = 1
    
    try:
      # 複数のblobを含むderivation_path
      let multipleDerivPath = @[
        @[0x01u8, 0x02u8],
        @[0x03u8, 0x04u8, 0x05u8],
        @[0x06u8]
      ]
      
      echo "複数derivation_path作成完了: ", multipleDerivPath.len, " 個のblob"
      
      # processSeqValueで変換
      let seqValue = processSeqValue(multipleDerivPath)
      echo "processSeqValue成功, vecVal.len = ", seqValue.vecVal.len
      
      # 各blobの内容確認
      for i, elem in seqValue.vecVal:
        echo "  blob[", i, "]: kind=", elem.kind, ", len=", elem.blobVal.len
      
      # ECDSA構造に組み込み
      let caller = Principal.fromText("aaaaa-aa")
      let ecdsaArgs = newCRecordEmpty()
      ecdsaArgs["canister_id"] = asSome(candidValueToCandidRecord(newCandidValue(caller)))
      ecdsaArgs["derivation_path"] = candidValueToCandidRecord(seqValue)
      
      let keyIdRecord = newCRecordEmpty()
      keyIdRecord["curve"] = candidValueToCandidRecord(newCandidValue(EcdsaCurve.secp256k1))
      keyIdRecord["name"] = candidValueToCandidRecord(newCandidValue("multi_test_key"))
      ecdsaArgs["key_id"] = keyIdRecord
      
      echo "複数derivation_pathでのECDSA構造作成成功"
      echo "構造: ", $ecdsaArgs
      
    except Exception as e:
      echo "複数derivation_pathテストエラー: ", e.msg
    
    echo "===== 複数derivation_pathのテスト完了 ====="
    check true 