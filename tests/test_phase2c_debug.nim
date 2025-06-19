import unittest
import std/options
import std/sequtils
import std/strutils
import std/tables
import ../src/nicp_cdk/ic_types/candid_types
import ../src/nicp_cdk/ic_types/ic_record
import ../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../src/nicp_cdk/ic_types/candid_message/candid_decode

# EcdsaCurve enumの定義
type
  EcdsaCurve* {.pure.} = enum
    secp256k1 = 0
    secp256r1 = 1

suite "Phase 2C Debug Tests":
  
  test "Debug vec blob encoding issue":
    echo "=== Phase 2C Debug: vec blob encoding ==="
    
    # caller.bytesから生成されたblobデータをシミュレート
    let blobCaller = @[0x1du8, 0x18u8, 0x92u8, 0x8cu8, 0x6eu8, 0x87u8, 0x15u8, 0xddu8, 
                       0xbeu8, 0x1bu8, 0x57u8, 0xbbu8, 0xf9u8, 0xf4u8, 0x7eu8, 0x7eu8,
                       0x98u8, 0x6bu8, 0x79u8, 0x76u8, 0x8bu8, 0x29u8, 0x3bu8, 0x56u8,
                       0xe4u8, 0xa3u8, 0x85u8, 0xa3u8, 0xbbu8]  # 29バイトのPrincipalデータ
    
    echo "Step 1: Creating derivation_path as seq[seq[uint8]]"
    let derivationPath = @[blobCaller]  # seq[seq[uint8]]
    echo "derivationPath length: ", derivationPath.len
    echo "blobCaller length: ", blobCaller.len
    
    echo "Step 2: Converting to CandidValue"
    let candidVec = newCandidValue(derivationPath)
    echo "candidVec.kind: ", candidVec.kind
    
    if candidVec.kind == ctVec:
      echo "Vec elements count: ", candidVec.vecVal.len
      echo "First element kind: ", candidVec.vecVal[0].kind
      
      if candidVec.vecVal[0].kind == ctBlob:
        echo "First blob element length: ", candidVec.vecVal[0].blobVal.len
        echo "First few bytes: ", candidVec.vecVal[0].blobVal[0..min(4, candidVec.vecVal[0].blobVal.len-1)]
      else:
        echo "ERROR: First element is not ctBlob, it's: ", candidVec.vecVal[0].kind
    
    echo "Step 3: Encoding CandidValue"
    try:
      let encoded = encodeCandidMessage(@[candidVec])
      echo "Encoding successful, length: ", encoded.len
      echo "Encoded bytes (hex): ", encoded.mapIt(it.toHex()).join("")
      
      echo "Step 4: Attempting to decode"
      let decoded = decodeCandidMessage(encoded)
      echo "Decoding successful"
      echo "Decoded values count: ", decoded.values.len
      
      if decoded.values.len > 0:
        echo "First decoded value kind: ", decoded.values[0].kind
        if decoded.values[0].kind == ctVec:
          echo "Decoded vec elements count: ", decoded.values[0].vecVal.len
          if decoded.values[0].vecVal.len > 0:
            echo "First decoded element kind: ", decoded.values[0].vecVal[0].kind
            
    except Exception as e:
      echo "Error during encoding/decoding: ", e.msg
      echo "Error details: ", e.getStackTrace()

  test "Debug simple blob encoding":
    echo "=== Phase 2C Debug: simple blob encoding ==="
    
    # まず単一のblobで問題を確認
    let singleBlob = @[0x74u8, 0x65u8, 0x73u8, 0x74u8]  # "test"
    echo "Single blob length: ", singleBlob.len
    
    let candidBlob = newCandidValue(singleBlob)
    echo "CandidBlob kind: ", candidBlob.kind
    
    try:
      let encoded = encodeCandidMessage(@[candidBlob])
      echo "Single blob encoding successful, length: ", encoded.len
      
      let decoded = decodeCandidMessage(encoded)
      echo "Single blob decoding successful"
      echo "Decoded blob kind: ", decoded.values[0].kind
      
    except Exception as e:
      echo "Error with single blob: ", e.msg

  test "Debug EcdsaCurve enum to variant":
    echo "=== Phase 2C Debug: EcdsaCurve enum to variant ==="
    
    try:
      let curve = EcdsaCurve.secp256k1
      echo "Enum value: ", curve
      
      let candidVariant = newCandidValue(curve)
      echo "Variant kind: ", candidVariant.kind
      
      if candidVariant.kind == ctVariant:
        echo "Variant tag: ", candidVariant.variantVal.tag
        echo "Variant value kind: ", candidVariant.variantVal.value.kind
        
        # エンコード/デコードテスト
        let encoded = encodeCandidMessage(@[candidVariant])
        echo "Enum encoding successful, length: ", encoded.len
        
        let decoded = decodeCandidMessage(encoded)
        echo "Enum decoding successful"
        echo "Decoded variant tag: ", decoded.values[0].variantVal.tag
        
    except Exception as e:
      echo "Error with enum conversion: ", e.msg
      echo "Error details: ", e.getStackTrace()

  test "Debug key_id record structure":
    echo "=== Phase 2C Debug: key_id record structure ==="
    
    try:
      echo "Step 1: Creating curve variant"
      let curve = newCandidValue(EcdsaCurve.secp256k1)
      echo "Curve created successfully"
      
      echo "Step 2: Creating name text"
      let name = newCandidText("dfx_test_key")
      echo "Name created successfully"
      
      echo "Step 3: Creating key_id record"
      var keyIdFields = initTable[string, CandidValue]()
      keyIdFields["curve"] = curve
      keyIdFields["name"] = name
      let keyIdRecord = newCandidRecord(keyIdFields)
      echo "Key_id record created successfully"
      
      echo "Step 4: Encoding key_id record"
      let encoded = encodeCandidMessage(@[keyIdRecord])
      echo "Key_id encoding successful, length: ", encoded.len
      
      echo "Step 5: Decoding key_id record"
      let decoded = decodeCandidMessage(encoded)
      echo "Key_id decoding successful"
      echo "Decoded record fields count: ", decoded.values[0].recordVal.fields.len
      
    except Exception as e:
      echo "Error with key_id record: ", e.msg
      echo "Error details: ", e.getStackTrace()

  test "Debug complete ECDSA structure step by step":
    echo "=== Phase 2C Debug: complete ECDSA structure ==="
    
    try:
      echo "Step 1: Creating canister_id (opt principal)"
      let canisterId = newCandidOpt(none(CandidValue))
      echo "Canister_id created successfully"
      
      echo "Step 2: Creating derivation_path (vec blob)"
      let blobData = @[0x74u8, 0x65u8, 0x73u8, 0x74u8]  # "test"
      let derivationPath = @[blobData]
      let derivationCandid = newCandidValue(derivationPath)
      echo "Derivation_path created successfully"
      
      echo "Step 3: Creating key_id record"
      var keyIdFields = initTable[string, CandidValue]()
      keyIdFields["curve"] = newCandidValue(EcdsaCurve.secp256k1)
      keyIdFields["name"] = newCandidText("dfx_test_key")
      let keyIdRecord = newCandidRecord(keyIdFields)
      echo "Key_id record created successfully"
      
      echo "Step 4: Creating complete ECDSA record"
      var ecdsaFields = initTable[string, CandidValue]()
      ecdsaFields["canister_id"] = canisterId
      ecdsaFields["derivation_path"] = derivationCandid
      ecdsaFields["key_id"] = keyIdRecord
      let ecdsaRecord = newCandidRecord(ecdsaFields)
      echo "Complete ECDSA record created successfully"
      
      echo "Step 5: Encoding complete ECDSA record"
      let encoded = encodeCandidMessage(@[ecdsaRecord])
      echo "Complete ECDSA encoding successful, length: ", encoded.len
      
      echo "Step 6: Decoding complete ECDSA record"
      let decoded = decodeCandidMessage(encoded)
      echo "Complete ECDSA decoding successful"
      echo "Decoded record fields count: ", decoded.values[0].recordVal.fields.len
      
    except Exception as e:
      echo "Error with complete ECDSA structure: ", e.msg
      echo "Error details: ", e.getStackTrace()
      echo "Error at step that failed - need to identify which step" 