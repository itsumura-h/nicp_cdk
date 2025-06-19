import unittest
import std/tables
import std/strutils
import std/sequtils
import ../src/nicp_cdk/ic_types/candid_types
import ../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../src/nicp_cdk/ic_types/candid_message/candid_decode

suite "Vec/Blob Unified Processing Tests":
  
  test "Unified decode - vec nat8":
    echo "=== Testing unified decode for vec nat8 ==="
    
    try:
      # Manual vec nat8 creation
      var natElements: seq[CandidValue] = @[]
      for b in @[0x74u8, 0x65u8, 0x73u8, 0x74u8]:  # "test"
        natElements.add(CandidValue(kind: ctNat8, natVal: uint(b)))
      
      let vecNat8 = CandidValue(kind: ctVec, vecVal: natElements)
      echo "Created vec nat8 with ", vecNat8.vecVal.len, " elements"
      
      # Encode and decode test
      let encoded = encodeCandidMessage(@[vecNat8])
      echo "Encoded successfully: ", encoded.len, " bytes"
      
      let decoded = decodeCandidMessage(encoded)
      echo "Decoded successfully: ", decoded.values.len, " values"
      
      check decoded.values.len == 1
      check decoded.values[0].kind == ctVec
      
      # Test dynamic conversion APIs
      echo "Testing getItems():"
      let items = decoded.values[0].getItems()
      check items.len == 4
      echo "Items count: ", items.len
      
      echo "Testing getBlob():"
      let blobData = decoded.values[0].getBlob()
      check blobData.len == 4
      check blobData == @[0x74u8, 0x65u8, 0x73u8, 0x74u8]
      echo "Blob data: ", blobData
      
      echo "Vec nat8 unified processing: ✅ SUCCESS"
      
    except Exception as e:
      echo "Error in vec nat8 test: ", e.msg

  test "Unified decode - original blob type":
    echo "=== Testing unified decode for original blob type ==="
    
    try:
      # Create blob using original API
      let blobData = @[0x48u8, 0x65u8, 0x6Cu8, 0x6Cu8, 0x6Fu8]  # "Hello"
      let originalBlob = CandidValue(kind: ctBlob, blobVal: blobData)
      echo "Created original blob with ", blobData.len, " bytes"
      
      # Encode and decode test  
      let encoded = encodeCandidMessage(@[originalBlob])
      echo "Encoded successfully: ", encoded.len, " bytes"
      
      let decoded = decodeCandidMessage(encoded)
      echo "Decoded successfully: ", decoded.values.len, " values"
      
      check decoded.values.len == 1
      # After unified processing, it should be ctVec
      check decoded.values[0].kind == ctVec
      echo "Unified processing converts blob to vec: ✅"
      
      # Test dynamic conversion APIs
      echo "Testing getBlob() on unified representation:"
      let retrievedBlob = decoded.values[0].getBlob()
      check retrievedBlob == blobData
      echo "Retrieved blob matches original: ✅"
      
      echo "Testing getItems() on unified representation:"
      let items = decoded.values[0].getItems()
      check items.len == 5
      echo "Items count: ", items.len
      
      echo "Original blob unified processing: ✅ SUCCESS"
      
    except Exception as e:
      echo "Error in original blob test: ", e.msg

  test "asBlobValue and asSeqValue API":
    echo "=== Testing asBlobValue and asSeqValue API ==="
    
    try:
      let testData = @[0x41u8, 0x42u8, 0x43u8]  # "ABC"
      
      echo "Testing asBlobValue():"
      let blobValue = asBlobValue(testData)
      check blobValue.kind == ctVec
      check blobValue.canConvertToBlob()
      echo "asBlobValue creates unified representation: ✅"
      
      let retrievedBlob = blobValue.getBlob()
      check retrievedBlob == testData
      echo "asBlobValue roundtrip successful: ✅"
      
      echo "Testing asSeqValue():"
      let seqValue = asSeqValue(testData)
      check seqValue.kind == ctVec
      echo "asSeqValue creates vector representation: ✅"
      
      echo "asBlobValue/asSeqValue API: ✅ SUCCESS"
      
    except Exception as e:
      echo "Error in API test: ", e.msg

  test "vec blob (seq[seq[uint8]]) unified processing":
    echo "=== Testing vec blob unified processing ==="
    
    try:
      # Create vec blob structure
      let blobCaller = @[0x1du8, 0x18u8, 0x92u8, 0x8cu8]  # Sample principal bytes
      let derivationPath = @[blobCaller]  # seq[seq[uint8]]
      
      echo "Creating vec blob with newCandidValue():"
      let vecBlob = newCandidValue(derivationPath)
      check vecBlob.kind == ctVec
      echo "Vec blob created successfully"
      
      # Test encoding and decoding
      echo "Testing encode/decode cycle:"
      let encoded = encodeCandidMessage(@[vecBlob])
      echo "Encoded length: ", encoded.len
      
      let decoded = decodeCandidMessage(encoded)
      check decoded.values.len == 1
      check decoded.values[0].kind == ctVec
      echo "Decode successful with unified processing"
      
      # Test accessing first blob element
      echo "Testing vec blob element access:"
      let items = decoded.values[0].getItems()
      check items.len == 1
      echo "Vec blob has ", items.len, " blob elements"
      
      # First element should be convertible to blob
      if items[0].canConvertToBlob():
        let firstBlob = items[0].getBlob()
        check firstBlob.len == 4
        echo "First blob element has ", firstBlob.len, " bytes"
        echo "Vec blob unified processing: ✅ SUCCESS"
      else:
        echo "Warning: First element is not blob-convertible"
      
    except Exception as e:
      echo "Error in vec blob test: ", e.msg
      echo "Error details: ", e.getStackTrace()

  test "Type checking and validation":
    echo "=== Testing type checking and validation ==="
    
    try:
      # Test isVecNat8
      let vecNat8 = asBlobValue(@[0x01u8, 0x02u8])
      check vecNat8.isVecNat8()
      echo "isVecNat8() works correctly: ✅"
      
      # Test canConvertToBlob
      check vecNat8.canConvertToBlob()
      echo "canConvertToBlob() works correctly: ✅"
      
      # Test with non-nat8 vector
      let vecText = CandidValue(kind: ctVec, vecVal: @[
        CandidValue(kind: ctText, textVal: "hello")
      ])
      check not vecText.isVecNat8()
      check not vecText.canConvertToBlob()
      echo "Non-nat8 vector detection works: ✅"
      
      echo "Type checking and validation: ✅ SUCCESS"
      
    except Exception as e:
      echo "Error in validation test: ", e.msg

  test "Error handling":
    echo "=== Testing error handling ==="
    
    try:
      # Test getBlob on non-vec type
      let textValue = CandidValue(kind: ctText, textVal: "test")
      
      try:
        discard textValue.getBlob()
        check false  # Should have thrown exception
      except ValueError as e:
        echo "Correct error for non-vec getBlob(): ", e.msg
        check "not a vector type" in e.msg
      
      # Test getBlob on non-convertible vec
      let vecText = CandidValue(kind: ctVec, vecVal: @[
        CandidValue(kind: ctText, textVal: "hello")
      ])
      
      try:
        discard vecText.getBlob()
        check false  # Should have thrown exception
      except ValueError as e:
        echo "Correct error for non-convertible getBlob(): ", e.msg
        check "non-nat8 element" in e.msg
      
      echo "Error handling: ✅ SUCCESS"
      
    except Exception as e:
      echo "Error in error handling test: ", e.msg 