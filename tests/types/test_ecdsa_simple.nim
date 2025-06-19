# nim c -r tests/types/test_ecdsa_simple.nim

import std/unittest
import std/options
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/ic_record
import ../../src/nicp_cdk/ic_types/ic_principal

# シンプルなECDSAテスト
suite "ECDSA Simple Tests":
  
  test "基本的なseq[seq[uint8]]処理":
    echo "===== 基本的なseq[seq[uint8]]処理 ====="
    
    # derivation_pathの作成
    let caller = Principal.fromText("aaaaa-aa")
    let derivationPath = @[caller.bytes]
    
    echo "derivationPath created, len: ", derivationPath.len
    
    # processSeqValueでの変換
    let seqValue = processSeqValue(derivationPath)
    echo "processSeqValue success, kind: ", seqValue.kind
    
    # CandidRecordに設定
    let record = newCRecordEmpty()
    record["test_field"] = candidValueToCandidRecord(seqValue)
    
    echo "Record created successfully: ", $record
    check true

  test "Enum型の基本処理":
    echo "===== Enum型の基本処理 ====="
    
    type TestCurve = enum
      curve1
      curve2
    
    # Enum値をCandidValueに変換
    let enumValue = newCandidValue(TestCurve.curve1)
    echo "Enum CandidValue created, kind: ", enumValue.kind
    
    # CandidRecordに設定
    let record = newCRecordEmpty()
    record["curve"] = candidValueToCandidRecord(enumValue)
    
    echo "Enum record created: ", $record
    check true

  test "ECDSA基本構造作成":
    echo "===== ECDSA基本構造作成 ====="
    
    type EcdsaCurve = enum
      secp256k1
      secp256r1
    
    let caller = Principal.fromText("aaaaa-aa")
    let derivationPath = @[caller.bytes]
    
    # 段階的に構造作成
    let ecdsaArgs = newCRecordEmpty()
    
    # Step 1: canister_id (None)
    ecdsaArgs["canister_id"] = newCOptionNone()
    echo "canister_id set"
    
    # Step 2: derivation_path
    let seqValue = processSeqValue(derivationPath)
    ecdsaArgs["derivation_path"] = candidValueToCandidRecord(seqValue)
    echo "derivation_path set"
    
    # Step 3: key_id record
    let keyIdRecord = newCRecordEmpty()
    keyIdRecord["curve"] = candidValueToCandidRecord(newCandidValue(EcdsaCurve.secp256k1))
    keyIdRecord["name"] = candidValueToCandidRecord(newCandidValue("dfx_test_key"))
    
    ecdsaArgs["key_id"] = keyIdRecord
    echo "key_id set"
    
    echo "ECDSA structure created successfully: ", $ecdsaArgs
    check true 