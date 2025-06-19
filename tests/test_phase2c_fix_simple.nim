import unittest
import std/tables
import ../src/nicp_cdk/ic_types/candid_types
import ../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../src/nicp_cdk/ic_types/candid_message/candid_decode

# EcdsaCurve enumの定義
type
  EcdsaCurve* {.pure.} = enum
    secp256k1 = 0
    secp256r1 = 1

suite "Phase 2C Simple Fix Tests":
  
  test "Test single variant encoding":
    echo "=== Testing single variant encoding ==="
    
    try:
      # まず単純なVariantを作成
      let curve = EcdsaCurve.secp256k1
      echo "Enum value: ", curve
      
      # 手動でVariantを作成（newCandidValueを使わない）
      let variantValue = CandidValue(
        kind: ctVariant,
        variantVal: CandidVariant(
          tag: 492384026u32,  # candidHash("secp256k1")の値
          value: CandidValue(kind: ctNull)
        )
      )
      
      echo "Manual variant created"
      echo "Variant kind: ", variantValue.kind
      echo "Variant tag: ", variantValue.variantVal.tag
      echo "Variant value kind: ", variantValue.variantVal.value.kind
      
      # エンコードを試す
      let encoded = encodeCandidMessage(@[variantValue])
      echo "Single variant encoding successful, length: ", encoded.len
      
      let decoded = decodeCandidMessage(encoded)
      echo "Single variant decoding successful"
      echo "Decoded variant tag: ", decoded.values[0].variantVal.tag
      
    except Exception as e:
      echo "Error with single variant: ", e.msg
      echo "Error details: ", e.getStackTrace()

  test "Test simple record with text field":
    echo "=== Testing simple record with text field ==="
    
    try:
      # まず簡単なRecordを作成（variantなし）
      var fields = initOrderedTable[string, CandidValue]()
      fields["name"] = CandidValue(kind: ctText, textVal: "test_name")
      
      let simpleRecord = CandidValue(
        kind: ctRecord,
        recordVal: CandidRecord(kind: ckRecord, fields: fields)
      )
      
      echo "Simple record created"
      echo "Record kind: ", simpleRecord.kind
      echo "Record fields count: ", simpleRecord.recordVal.fields.len
      
      # エンコードを試す
      let encoded = encodeCandidMessage(@[simpleRecord])
      echo "Simple record encoding successful, length: ", encoded.len
      
      let decoded = decodeCandidMessage(encoded)
      echo "Simple record decoding successful"
      echo "Decoded record fields count: ", decoded.values[0].recordVal.fields.len
      
    except Exception as e:
      echo "Error with simple record: ", e.msg
      echo "Error details: ", e.getStackTrace()

  test "Test record with variant step by step":
    echo "=== Testing record with variant step by step ==="
    
    try:
      echo "Step 1: Creating variant value"
      let variantValue = CandidValue(
        kind: ctVariant,
        variantVal: CandidVariant(
          tag: 492384026u32,  # candidHash("secp256k1")
          value: CandidValue(kind: ctNull)
        )
      )
      echo "Variant created successfully"
      
      echo "Step 2: Creating text value"
      let textValue = CandidValue(kind: ctText, textVal: "dfx_test_key")
      echo "Text created successfully"
      
      echo "Step 3: Creating record fields"
      var fields = initOrderedTable[string, CandidValue]()
      fields["curve"] = variantValue
      fields["name"] = textValue
      echo "Fields created successfully"
      
      echo "Step 4: Creating record"
      let recordValue = CandidValue(
        kind: ctRecord,
        recordVal: CandidRecord(kind: ckRecord, fields: fields)
      )
      echo "Record created successfully"
      
      echo "Step 5: Encoding record"
      let encoded = encodeCandidMessage(@[recordValue])
      echo "Record encoding successful, length: ", encoded.len
      
      echo "Step 6: Decoding record"
      let decoded = decodeCandidMessage(encoded)
      echo "Record decoding successful"
      echo "Decoded record fields count: ", decoded.values[0].recordVal.fields.len
      
    except Exception as e:
      echo "Error with record+variant: ", e.msg
      echo "Error details: ", e.getStackTrace()
      echo "Error at step - need to identify specific step" 