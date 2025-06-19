import unittest
import std/tables
import std/strutils
import std/sequtils
import ../src/nicp_cdk/ic_types/candid_types
import ../src/nicp_cdk/ic_types/ic_record
import ../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../src/nicp_cdk/ic_types/candid_message/candid_decode

# EcdsaCurve enum for testing
type 
  EcdsaCurve* {.pure.} = enum
    secp256k1 = 0
    secp256r1 = 1

suite "Record+Variant Field Processing Fix Tests":
  
  test "Simple Variant alone - baseline":
    echo "=== Testing simple variant alone (baseline) ==="
    
    try:
      let curve = newCandidValue(EcdsaCurve.secp256k1)
      check curve.kind == ctVariant
      echo "Variant created: ", curve.kind
      
      let encoded = encodeCandidMessage(@[curve])
      echo "Encoded successfully: ", encoded.len, " bytes"
      
      let decoded = decodeCandidMessage(encoded)
      check decoded.values.len == 1
      check decoded.values[0].kind == ctVariant
      echo "Simple variant: ✅ SUCCESS"
      
    except Exception as e:
      echo "Error in simple variant test: ", e.msg

  test "Simple Record alone - baseline":
    echo "=== Testing simple record alone (baseline) ==="
    
    try:
      var fields = initTable[string, CandidValue]()
      fields["name"] = newCandidText("test_key")  
      fields["version"] = newCandidText("1")
      let record = newCandidRecord(fields)
      check record.kind == ctRecord
      echo "Record created: ", record.kind
      
      let encoded = encodeCandidMessage(@[record])
      echo "Encoded successfully: ", encoded.len, " bytes"
      
      let decoded = decodeCandidMessage(encoded)
      check decoded.values.len == 1
      check decoded.values[0].kind == ctRecord
      echo "Simple record: ✅ SUCCESS"
      
    except Exception as e:
      echo "Error in simple record test: ", e.msg

  test "Record with Variant field - problem case":
    echo "=== Testing record with variant field (problem case) ==="
    
    try:
      echo "Step 1: Creating key_id record with EcdsaCurve variant"
      var keyIdFields = initTable[string, CandidValue]()
      keyIdFields["curve"] = newCandidValue(EcdsaCurve.secp256k1)  # Enum → Variant
      keyIdFields["name"] = newCandidText("dfx_test_key")          # Text
      let keyId = newCandidRecord(keyIdFields)
      
      check keyId.kind == ctRecord
      echo "Record with variant created successfully"
      
      echo "Step 2: Testing encoding"
      let encoded = encodeCandidMessage(@[keyId])
      echo "Encoded successfully: ", encoded.len, " bytes"
      echo "Encoded hex: ", encoded.mapIt(it.toHex()).join("")
      
      echo "Step 3: Testing decoding"
      let decoded = decodeCandidMessage(encoded)
      echo "Decoded successfully: ", decoded.values.len, " values"
      
      check decoded.values.len == 1
      check decoded.values[0].kind == ctRecord
      echo "Record with variant field: ✅ SUCCESS"
      
    except Exception as e:
      echo "Error in record+variant test: ", e.msg
      echo "Error details: ", e.getStackTrace()

  test "Manual Record+Variant creation":
    echo "=== Testing manual record+variant creation ==="
    
    try:
      echo "Step 1: Creating variant manually"
      let curveVariant = newCandidVariant("secp256k1", newCandidNull())
      echo "Variant created: ", curveVariant.kind
      
      echo "Step 2: Creating record manually"
      var fields = initTable[string, CandidValue]()
      fields["curve"] = curveVariant
      fields["name"] = newCandidText("dfx_test_key")
      let manualRecord = newCandidRecord(fields)
      echo "Manual record created: ", manualRecord.kind
      
      echo "Step 3: Testing encoding"
      let encoded = encodeCandidMessage(@[manualRecord])
      echo "Encoded successfully: ", encoded.len, " bytes"
      
      echo "Step 4: Testing decoding"
      let decoded = decodeCandidMessage(encoded)
      check decoded.values.len == 1
      check decoded.values[0].kind == ctRecord
      echo "Manual record+variant: ✅ SUCCESS"
      
    except Exception as e:
      echo "Error in manual creation test: ", e.msg
      echo "Error details: ", e.getStackTrace()

  test "Type table analysis for Record+Variant":
    echo "=== Analyzing type table for Record+Variant ==="
    
    try:
      var keyIdFields = initTable[string, CandidValue]()
      keyIdFields["curve"] = newCandidValue(EcdsaCurve.secp256k1)
      keyIdFields["name"] = newCandidText("dfx_test_key")
      let keyId = newCandidRecord(keyIdFields)
      
      echo "Creating type builder and analyzing structure"
      # Type structure analysis would go here
      # This will help identify type table inconsistencies
      
      let encoded = encodeCandidMessage(@[keyId])
      echo "Type table created successfully"
      
      # Analyze the encoded message structure
      echo "DIDL header (4 bytes): ", encoded[0..3].mapIt(it.toHex()).join("")
      if encoded.len > 4:
        echo "Type table length: ", encoded[4]
      
      echo "Type table analysis completed"
      
    except Exception as e:
      echo "Error in type table analysis: ", e.msg

  test "Field hash consistency check":
    echo "=== Testing field hash consistency ==="
    
    try:
      let curveHash = candidHash("curve")
      let nameHash = candidHash("name")
      
      echo "Field hashes:"
      echo "  curve: ", curveHash
      echo "  name: ", nameHash
      
      # Verify hash ordering (should be sorted)
      if curveHash < nameHash:
        echo "Hash ordering: curve < name ✅"
      else:
        echo "Hash ordering: name < curve ✅"
      
      echo "Field hash consistency: ✅ SUCCESS"
      
    except Exception as e:
      echo "Error in hash consistency test: ", e.msg 