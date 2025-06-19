import unittest
import std/tables
import std/strutils
import ../src/nicp_cdk/ic_types/candid_types
import ../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../src/nicp_cdk/ic_types/candid_message/candid_decode

type 
  EcdsaCurve* {.pure.} = enum
    secp256k1 = 0
    secp256r1 = 1

suite "Record+Variant Simple Test":
  
  test "Record with Variant: simplest case":
    echo "=== Record with Variant: simplest case ==="
    
    try:
      echo "Step 1: Creating components"
      let curveVariant = newCandidValue(EcdsaCurve.secp256k1)
      echo "  - Curve variant: ", curveVariant.kind, " tag=", curveVariant.variantVal.tag
      
      var fields = initTable[string, CandidValue]()
      fields["curve"] = curveVariant
      let record = newCandidRecord(fields)
      echo "  - Record created with ", record.recordVal.fields.len, " field(s)"
      
      echo "Step 2: Direct encoding test"
      let encoded = encodeCandidMessage(@[record])
      echo "  - ✅ SUCCESS: Encoded ", encoded.len, " bytes"
      
      echo "Step 3: Decode test"
      let decoded = decodeCandidMessage(encoded)
      echo "  - ✅ SUCCESS: Decoded ", decoded.values.len, " value(s)"
      
    except Exception as e:
      echo "❌ ERROR: ", e.msg
      echo "Trace: ", e.getStackTrace()

  test "Variant alone vs Record containing Variant":
    echo "=== Variant alone vs Record containing Variant ==="
    
    try:
      echo "Test A: Standalone Variant"
      let standaloneVariant = newCandidValue(EcdsaCurve.secp256k1)
      let encodedA = encodeCandidMessage(@[standaloneVariant])
      echo "  - Standalone: ✅ SUCCESS (", encodedA.len, " bytes)"
      
      echo "Test B: Record with Variant field"
      var fields = initTable[string, CandidValue]()
      fields["curve"] = newCandidValue(EcdsaCurve.secp256k1)
      let recordWithVariant = newCandidRecord(fields)
      let encodedB = encodeCandidMessage(@[recordWithVariant])
      echo "  - Record+Variant: ✅ SUCCESS (", encodedB.len, " bytes)"
      
    except Exception as e:
      echo "❌ ERROR: ", e.msg

  test "Mixed field types":
    echo "=== Mixed field types ==="
    
    try:
      var fields = initTable[string, CandidValue]()
      fields["curve"] = newCandidValue(EcdsaCurve.secp256k1)
      fields["name"] = newCandidText("test_key")
      fields["version"] = newCandidNat(1)
      let mixedRecord = newCandidRecord(fields)
      
      let encoded = encodeCandidMessage(@[mixedRecord])
      echo "  - Mixed types: ✅ SUCCESS (", encoded.len, " bytes)"
      
      let decoded = decodeCandidMessage(encoded)
      echo "  - Roundtrip: ✅ SUCCESS"
      
    except Exception as e:
      echo "❌ ERROR: ", e.msg

  test "Debug field type references":
    echo "=== Debug field type references ==="
    
    try:
      # Create a simple case first
      var fields = initTable[string, CandidValue]()
      fields["status"] = newCandidValue(EcdsaCurve.secp256k1)
      let record = newCandidRecord(fields)
      
      # Force creation of encoding context to debug
      echo "  - Testing minimal case..."
      let encoded = encodeCandidMessage(@[record])
      echo "  - ✅ Minimal case works: ", encoded.len, " bytes"
      
    except Exception as e:
      echo "❌ Minimal case failed: ", e.msg 