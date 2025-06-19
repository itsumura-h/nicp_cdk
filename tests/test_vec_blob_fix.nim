import unittest
import std/tables
import std/strutils
import std/sequtils
import ../src/nicp_cdk/ic_types/candid_types
import ../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../src/nicp_cdk/ic_types/candid_message/candid_decode

suite "Vec Blob Fix Tests":
  
  test "Analyze vec blob encoding structure":
    echo "=== Analyzing vec blob encoding structure ==="
    
    try:
      # caller.bytesから生成されたblobデータをシミュレート
      let blobCaller = @[0x1du8, 0x18u8, 0x92u8, 0x8cu8, 0x6eu8, 0x87u8, 0x15u8, 0xddu8, 
                         0xbeu8, 0x1bu8, 0x57u8, 0xbbu8, 0xf9u8, 0xf4u8, 0x7eu8, 0x7eu8,
                         0x98u8, 0x6bu8, 0x79u8, 0x76u8, 0x8bu8, 0x29u8, 0x3bu8, 0x56u8,
                         0xe4u8, 0xa3u8, 0x85u8, 0xa3u8, 0xbbu8]  # 29バイトのPrincipalデータ
      
      echo "Step 1: Creating vec blob structure"
      let derivationPath = @[blobCaller]  # seq[seq[uint8]]
      echo "derivationPath type: seq[seq[uint8]]"
      echo "derivationPath length: ", derivationPath.len
      echo "First blob length: ", derivationPath[0].len
      
      echo "Step 2: Converting to CandidValue"
      let derivationCandid = newCandidValue(derivationPath)
      echo "CandidValue kind: ", derivationCandid.kind
      
      if derivationCandid.kind == ctVec:
        echo "Vec elements count: ", derivationCandid.vecVal.len
        if derivationCandid.vecVal.len > 0:
          echo "First element kind: ", derivationCandid.vecVal[0].kind
          if derivationCandid.vecVal[0].kind == ctBlob:
            echo "First blob length: ", derivationCandid.vecVal[0].blobVal.len
          elif derivationCandid.vecVal[0].kind == ctVec:
            echo "First element is vec, not blob. Elements count: ", derivationCandid.vecVal[0].vecVal.len
            if derivationCandid.vecVal[0].vecVal.len > 0:
              echo "First sub-element kind: ", derivationCandid.vecVal[0].vecVal[0].kind
      
      echo "Step 3: Analyzing encoded message"
      let encoded = encodeCandidMessage(@[derivationCandid])
      echo "Encoded length: ", encoded.len
      echo "Encoded hex: ", encoded.mapIt(it.toHex()).join("")
      
      # ヘッダー分析
      echo "Magic header (first 4 bytes): ", encoded[0..3].mapIt(it.toHex()).join("")
      
      # 型テーブル長 (byte 4)
      if encoded.len > 4:
        echo "Type table length: ", encoded[4]
      
      echo "Step 4: Testing decode"
      let decoded = decodeCandidMessage(encoded)
      echo "Decode successful"
      echo "Decoded values count: ", decoded.values.len
      
      if decoded.values.len > 0:
        echo "First decoded value kind: ", decoded.values[0].kind
        if decoded.values[0].kind == ctVec:
          echo "Decoded vec elements: ", decoded.values[0].vecVal.len
          if decoded.values[0].vecVal.len > 0:
            echo "First decoded element kind: ", decoded.values[0].vecVal[0].kind
            
    except Exception as e:
      echo "Error in vec blob analysis: ", e.msg
      echo "Error details: ", e.getStackTrace()

  test "Compare single blob vs vec blob":
    echo "=== Comparing single blob vs vec blob ==="
    
    try:
      let testData = @[0x74u8, 0x65u8, 0x73u8, 0x74u8]  # "test"
      
      echo "Test 1: Single blob"
      let singleBlob = newCandidValue(testData)
      echo "Single blob kind: ", singleBlob.kind
      let encodedSingle = encodeCandidMessage(@[singleBlob])
      echo "Single blob encoded length: ", encodedSingle.len
      echo "Single blob hex: ", encodedSingle.mapIt(it.toHex()).join("")
      
      echo "Test 2: Vec blob (seq[seq[uint8]])"
      let vecBlob = newCandidValue(@[testData])
      echo "Vec blob kind: ", vecBlob.kind
      if vecBlob.kind == ctVec:
        echo "Vec elements: ", vecBlob.vecVal.len
        if vecBlob.vecVal.len > 0:
          echo "First element kind: ", vecBlob.vecVal[0].kind
      
      let encodedVec = encodeCandidMessage(@[vecBlob])
      echo "Vec blob encoded length: ", encodedVec.len
      echo "Vec blob hex: ", encodedVec.mapIt(it.toHex()).join("")
      
      echo "Test 3: Decode comparison"
      let decodedSingle = decodeCandidMessage(encodedSingle)
      echo "Single decode kind: ", decodedSingle.values[0].kind
      
      let decodedVec = decodeCandidMessage(encodedVec)
      echo "Vec decode kind: ", decodedVec.values[0].kind
      
    except Exception as e:
      echo "Error in comparison test: ", e.msg

  test "Test explicit vec nat8 creation":
    echo "=== Testing explicit vec nat8 creation ==="
    
    try:
      let testData = @[0x74u8, 0x65u8, 0x73u8, 0x74u8]  # "test"
      
      echo "Creating vec nat8 manually"
      # Manual vec nat8 creation
      var natElements: seq[CandidValue] = @[]
      for b in testData:
        natElements.add(CandidValue(kind: ctNat8, natVal: uint(b)))
      
      let vecNat8 = CandidValue(kind: ctVec, vecVal: natElements)
      echo "Vec nat8 kind: ", vecNat8.kind
      echo "Vec nat8 elements: ", vecNat8.vecVal.len
      
      let encoded = encodeCandidMessage(@[vecNat8])
      echo "Vec nat8 encoded length: ", encoded.len
      echo "Vec nat8 hex: ", encoded.mapIt(it.toHex()).join("")
      
      let decoded = decodeCandidMessage(encoded)
      echo "Vec nat8 decode successful"
      echo "Decoded kind: ", decoded.values[0].kind
      
    except Exception as e:
      echo "Error in vec nat8 test: ", e.msg
      echo "Error details: ", e.getStackTrace() 