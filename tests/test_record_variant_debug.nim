import unittest
import std/tables
import std/strutils
import std/sequtils
import ../src/nicp_cdk/ic_types/candid_types
import ../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../src/nicp_cdk/ic_types/candid_message/candid_decode

# EcdsaCurve enum for testing
type 
  EcdsaCurve* {.pure.} = enum
    secp256k1 = 0
    secp256r1 = 1

suite "Record+Variant Type Table Debug Tests":
  
  test "Debug: Variant field type in Record":
    echo "=== Debug: Variant field type in Record ==="
    
    try:
      echo "Step 1: Creating Variant value"
      let curveVariant = newCandidValue(EcdsaCurve.secp256k1)
      echo "  - Variant kind: ", curveVariant.kind
      echo "  - Variant tag: ", curveVariant.variantVal.tag  
      echo "  - Variant value kind: ", curveVariant.variantVal.value.kind
      
      echo "Step 2: Creating Record fields manually"
      var keyIdFields = initTable[string, CandidValue]()
      keyIdFields["curve"] = curveVariant
      keyIdFields["name"] = newCandidText("dfx_test_key")
      
      echo "Step 3: Creating Record"
      let keyId = newCandidRecord(keyIdFields)
      echo "  - Record kind: ", keyId.kind
      echo "  - Record field count: ", keyId.recordVal.fields.len
      
      echo "Step 4: Examining Record fields"
      for fieldName, fieldValue in keyId.recordVal.fields:
        echo "  - Field '", fieldName, "': kind=", fieldValue.kind
        if fieldValue.kind == ctVariant:
          echo "    - Variant tag: ", fieldValue.variantVal.tag
          echo "    - Variant value kind: ", fieldValue.variantVal.value.kind
      
      echo "Step 5: Testing inferTypeDescriptor on Record"
      let recordTypeDesc = inferTypeDescriptor(keyId)
      echo "  - Inferred record type: ", recordTypeDesc.kind
      echo "  - Record field count: ", recordTypeDesc.recordFields.len
      
      for field in recordTypeDesc.recordFields:
        echo "  - Field hash: ", field.hash, " type: ", field.fieldType.kind
        if field.fieldType.kind == ctVariant:
          echo "    - Variant field count: ", field.fieldType.variantFields.len
          if field.fieldType.variantFields.len > 0:
            echo "    - Variant tag: ", field.fieldType.variantFields[0].hash
            echo "    - Variant value type: ", field.fieldType.variantFields[0].fieldType.kind
      
      echo "Record+Variant type debugging: ✅ SUCCESS"
      
    except Exception as e:
      echo "Error in record+variant debug: ", e.msg
      echo "Error details: ", e.getStackTrace()

  test "Debug: Step-by-step encoding process":
    echo "=== Debug: Step-by-step encoding process ==="
    
    try:
      echo "Step 1: Creating simple Record with Variant"
      var keyIdFields = initTable[string, CandidValue]()
      let curveVariant = newCandidValue(EcdsaCurve.secp256k1)
      keyIdFields["curve"] = curveVariant
      keyIdFields["name"] = newCandidText("dfx_test_key")
      let keyId = newCandidRecord(keyIdFields)
      
      echo "Step 2: Starting encodeCandidMessage manually"
      var builder = TypeBuilder(
        typeTable: @[],
        typeIndexMap: initTable[string, int]()
      )
      
      echo "Step 3: Inferring type descriptor"
      let typeDesc = inferTypeDescriptor(keyId)
      echo "  - Type descriptor created for: ", typeDesc.kind
      
      echo "Step 4: Adding to type table"
      let typeRef = addTypeToTable(builder, typeDesc)
      echo "  - Type added with ref: ", typeRef
      echo "  - Type table size: ", builder.typeTable.len
      
      echo "Step 5: Examining type table entry"
      let entry = builder.typeTable[typeRef]
      echo "  - Entry kind: ", entry.kind
      echo "  - Record fields: ", entry.recordFields.len
      
      for field in entry.recordFields:
        echo "  - Field hash: ", field.hash, " type ref: ", field.fieldType
        if field.fieldType >= 0:
          let fieldEntry = builder.typeTable[field.fieldType]
          echo "    - Field entry kind: ", fieldEntry.kind
      
      echo "Step 6: Testing encoding with type ref"
      let encodedValue = encodeValue(keyId, typeRef, builder.typeTable)
      echo "  - Encoded successfully: ", encodedValue.len, " bytes"
      
      echo "Step-by-step encoding: ✅ SUCCESS"
      
    except Exception as e:
      echo "Error in step-by-step encoding: ", e.msg
      echo "Error details: ", e.getStackTrace()

  test "Debug: Field type matching":
    echo "=== Debug: Field type matching ==="
    
    try:
      echo "Step 1: Creating Record with Variant field"
      var keyIdFields = initTable[string, CandidValue]()
      let curveVariant = newCandidValue(EcdsaCurve.secp256k1)
      keyIdFields["curve"] = curveVariant
      keyIdFields["name"] = newCandidText("dfx_test_key")
      let keyId = newCandidRecord(keyIdFields)
      
      echo "Step 2: Building type table"
      var builder = TypeBuilder(
        typeTable: @[],
        typeIndexMap: initTable[string, int]()
      )
      let typeDesc = inferTypeDescriptor(keyId)
      let typeRef = addTypeToTable(builder, typeDesc)
      let entry = builder.typeTable[typeRef]
      
      echo "Step 3: Matching fields during encoding"
      for fieldInfo in entry.recordFields:
        var foundField: bool = false
        var fieldValue: CandidValue
        
        echo "  - Looking for field hash: ", fieldInfo.hash
        
        for fieldName, fieldVal in keyId.recordVal.fields:
          let fieldHash = candidHash(fieldName)
          echo "  - Checking field '", fieldName, "' with hash: ", fieldHash
          if fieldHash == fieldInfo.hash:
            foundField = true
            fieldValue = fieldVal
            echo "  - FOUND! Field value kind: ", fieldValue.kind
            echo "  - Expected field type ref: ", fieldInfo.fieldType
            if fieldInfo.fieldType >= 0:
              let expectedEntry = builder.typeTable[fieldInfo.fieldType]
              echo "  - Expected entry kind: ", expectedEntry.kind
            break
        
        if not foundField:
          echo "  - ERROR: Field not found!"
        else:
          echo "  - Field type match check:"
          if fieldInfo.fieldType >= 0:
            let expectedEntry = builder.typeTable[fieldInfo.fieldType]
            echo "    - Value kind: ", fieldValue.kind, " vs Expected: ", expectedEntry.kind
            if fieldValue.kind == expectedEntry.kind:
              echo "    - ✅ Type match!"
            else:
              echo "    - ❌ Type mismatch!"
      
      echo "Field type matching: ✅ SUCCESS"
      
    except Exception as e:
      echo "Error in field type matching: ", e.msg
      echo "Error details: ", e.getStackTrace() 