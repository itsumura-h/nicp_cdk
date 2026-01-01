import std/endians
import std/options
import std/algorithm
import std/tables
import ../../algorithm/leb128
import ../consts
import ../candid_types
import ../ic_principal
import ./candid_message_types


#---- Convert Type Tag Byte to CandidType ----
# proc parseTypeTag(b: byte): CandidType =
#   ## Parse a byte and return a CandidType
#   case b
#   of tagNull:           ctNull # 0x7f
#   of tagBool:           ctBool # 0x7e
#   of tagNat:            ctNat # 0x7d
#   of tagInt:            ctInt # 0x7c
#   of tagNat8:           ctNat8 # 0x7b
#   of tagNat16:          ctNat16 # 0x7a
#   of tagNat32:          ctNat32 # 0x79
#   of tagNat64:          ctNat64 # 0x78
#   of tagInt8:           ctInt8 # 0x77
#   of tagInt16:          ctInt16 # 0x76
#   of tagInt32:          ctInt32 # 0x75
#   of tagInt64:          ctInt64 # 0x74
#   of tagFloat32:        ctFloat32 # 0x73
#   of tagFloat64:        ctFloat64 # 0x72
#   of tagText:           ctText # 0x71
#   of tagReserved:       ctReserved # 0x70
#   of tagEmpty:          ctEmpty # 0x6f
#   of tagRecord:         ctRecord # 0x6c
#   of tagVariant:        ctVariant # 0x6b
#   of tagOptional:       ctOpt # 0x6e
#   of tagVec:            ctVec # 0x6d
#   of tagFunc:           ctFunc # 0x6a
#   of tagService:        ctService # 0x69
#   of tagQuery:          ctQuery # 0x01
#   of tagOneway:         ctOneway # 0x02
#   of tagCompositeQuery: ctCompositeQuery # 0x03
#   of tagPrincipal:      ctPrincipal # 0x68
#   else:
#     quit("Unknown Candid tag: " & $b)

# ================================================================================
# Private Procedures
# ================================================================================
proc typeCodeToCandidType(typeCode: int): CandidType =
  ## Converts a type code to CandidType
  case typeCode:
  of -1: ctNull
  of -2: ctBool
  of -3: ctNat
  of -4: ctInt
  of -5: ctNat8
  of -6: ctNat16
  of -7: ctNat32
  of -8: ctNat64
  of -9: ctInt8
  of -10: ctInt16
  of -11: ctInt32
  of -12: ctInt64
  of -13: ctFloat32
  of -14: ctFloat64
  of -15: ctText
  of -16: ctReserved
  of -17: ctEmpty
  of -18: ctOpt
  of -19: ctVec
  of -20: ctRecord
  of -21: ctVariant
  of -22: ctFunc
  of -23: ctService
  of -24: ctPrincipal
  else:
    raise newException(CandidDecodeError, "Unknown type code: " & $typeCode)


proc decodeTypeTableEntry(data: seq[byte], offset: var int): TypeTableEntry =
  ## Decodes a type table entry
  let typeCode = decodeSLEB128(data, offset)
  let candidType = typeCodeToCandidType(typeCode)
  
  result = TypeTableEntry(kind: candidType)
  
  case candidType:
  of ctRecord:
    let fieldCount = decodeULEB128(data, offset)
    result.recordFields = newSeq[tuple[hash: uint32, fieldType: int]](int(fieldCount))
    for i in 0..<int(fieldCount):
      let hash = uint32(decodeULEB128(data, offset))
      let fieldType = decodeSLEB128(data, offset)
      result.recordFields[i] = (hash: hash, fieldType: fieldType)
    # Sort fields by hash order
    result.recordFields.sort(proc(a, b: tuple[hash: uint32, fieldType: int]): int = 
      cmp(a.hash, b.hash))
  
  of ctVariant:
    let fieldCount = decodeULEB128(data, offset)
    result.variantFields = newSeq[tuple[hash: uint32, fieldType: int]](int(fieldCount))
    for i in 0..<int(fieldCount):
      let hash = uint32(decodeULEB128(data, offset))
      let fieldType = decodeSLEB128(data, offset)
      result.variantFields[i] = (hash: hash, fieldType: fieldType)
    # Sort fields by hash order
    result.variantFields.sort(proc(a, b: tuple[hash: uint32, fieldType: int]): int = 
      cmp(a.hash, b.hash))
  
  of ctOpt:
    result.optInnerType = decodeSLEB128(data, offset)
  
  of ctVec:
    result.vecElementType = decodeSLEB128(data, offset)
  
  of ctBlob:
    # Blob is processed as vec nat8, but only the element type is checked
    let elementType = decodeSLEB128(data, offset)
    # Error if not nat8 (though not strictly for Blob, for consistency)
    if elementType != typeCodeFromCandidType(ctNat8):
      raise newException(CandidDecodeError, "Blob element type must be nat8")
  
  of ctFunc:
    let argCount = decodeULEB128(data, offset)
    result.funcArgs = newSeq[int](int(argCount))
    for i in 0..<int(argCount):
      result.funcArgs[i] = decodeSLEB128(data, offset)
    
    let returnCount = decodeULEB128(data, offset)
    result.funcReturns = newSeq[int](int(returnCount))
    for i in 0..<int(returnCount):
      result.funcReturns[i] = decodeSLEB128(data, offset)
    
    let annotationLength = decodeULEB128(data, offset)
    result.funcAnnotations = newSeq[byte](int(annotationLength))
    for i in 0..<int(annotationLength):
      result.funcAnnotations[i] = data[offset]
      inc offset
  
  of ctService:
    let methodCount = decodeULEB128(data, offset)
    result.serviceMethods = newSeq[tuple[hash: uint32, methodType: int]](int(methodCount))
    for i in 0..<int(methodCount):
      let hash = uint32(decodeULEB128(data, offset))
      let methodType = decodeSLEB128(data, offset)
      result.serviceMethods[i] = (hash: hash, methodType: methodType)
    # Sort methods by hash order
    result.serviceMethods.sort(proc(a, b: tuple[hash: uint32, methodType: int]): int = 
      cmp(a.hash, b.hash))
  
  else:
    discard


proc decodePrimitiveValue(data: seq[byte], offset: var int, candidType: CandidType): CandidValue =
  ## Decodes a primitive value
  result = CandidValue(kind: candidType)
  
  case candidType:
  of ctNull:
    discard  # Null has no value
  
  of ctBool:
    if offset >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    result.boolVal = data[offset] != 0
    inc offset
  
  of ctNat:
    result.natVal = uint(decodeULEB128(data, offset))

  of ctNat8:
    if offset >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    result.nat8Val = uint8(data[offset])
    inc offset
  
  of ctNat16:
    if offset + 1 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: uint16
    littleEndian16(addr val, unsafeAddr data[offset])
    result.nat16Val = val
    offset += 2
  
  of ctNat32:
    if offset + 3 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: uint32
    littleEndian32(addr val, unsafeAddr data[offset])
    result.nat32Val = val
    offset += 4
  
  of ctNat64:
    if offset + 7 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: uint64
    littleEndian64(addr val, unsafeAddr data[offset])
    result.nat64Val = val
    offset += 8
  
  of ctInt:
    result.intVal = decodeSLEB128(data, offset)

  of ctInt8:
    if offset >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    result.int8Val = cast[int8](data[offset])
    inc offset
  
  of ctInt16:
    if offset + 1 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: int16
    littleEndian16(addr val, unsafeAddr data[offset])
    result.int16Val = val
    offset += 2
  
  of ctInt32:
    if offset + 3 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: int32
    littleEndian32(addr val, unsafeAddr data[offset])
    result.int32Val = val
    offset += 4
  
  of ctInt64:
    if offset + 7 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: int64
    littleEndian64(addr val, unsafeAddr data[offset])
    result.int64Val = val
    offset += 8
  
  of ctFloat32:
    if offset + 3 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: float32
    littleEndian32(addr val, unsafeAddr data[offset])
    result.float32Val = val
    offset += 4
  
  of ctFloat64:
    if offset + 7 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: float64
    littleEndian64(addr val, unsafeAddr data[offset])
    result.float64Val = val
    offset += 8
  
  of ctText:
    let textLength = decodeULEB128(data, offset)
    if offset + int(textLength) > data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    result.textVal = newString(int(textLength))
    for i in 0..<int(textLength):
      result.textVal[i] = char(data[offset + i])
    offset += int(textLength)
  
  of ctPrincipal:
    # Skip ID form identifier (value should be 1)
    let idForm = data[offset]
    inc offset
    if idForm != 1:
      raise newException(CandidDecodeError, "Invalid principal ID form: " & $idForm)
    
    let principalLength = decodeULEB128(data, offset)
    if offset + int(principalLength) > data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    let principalBytes = data[offset..<offset + int(principalLength)]
    result.principalVal = Principal.fromBlob(principalBytes)
    offset += int(principalLength)
  
  of ctReserved:
    # reserved ignores the value
    discard
  
  of ctEmpty:
    # empty has no value (does nothing)
    discard
  
  else:
    raise newException(CandidDecodeError, "Unexpected primitive type: " & $candidType)


proc decodeValue(data: seq[byte], offset: var int, typeRef: int, typeTable: seq[TypeTableEntry]): CandidValue =
  proc decodeCompositeValue(data: seq[byte], offset: var int, typeEntry: TypeTableEntry, typeTable: seq[TypeTableEntry]): CandidValue =
    ## Decodes a composite value
    result = CandidValue(kind: typeEntry.kind)
    case typeEntry.kind:
    of ctRecord:
      result.recordVal = CandidRecord(kind: ckRecord, fields: initOrderedTable[string, CandidValue]())
      # Fields are ordered by the type table definition
      for fieldInfo in typeEntry.recordFields:
        let fieldValue = decodeValue(data, offset, fieldInfo.fieldType, typeTable)
        # Use hash value as field name (actual implementation requires reverse lookup of names)
        result.recordVal.fields[$fieldInfo.hash] = fieldValue
    of ctVariant:
      let tagIndex = decodeULEB128(data, offset)
      if int(tagIndex) >= typeEntry.variantFields.len:
        raise newException(CandidDecodeError, "Invalid variant tag index: " & $tagIndex)
      let selectedField = typeEntry.variantFields[tagIndex]
      let fieldValue = decodeValue(data, offset, selectedField.fieldType, typeTable)
      result.variantVal = CandidVariant(
        tag: selectedField.hash,
        value: fieldValue
      )
    of ctOpt:
      let hasValue = decodeULEB128(data, offset)
      if hasValue == 0:
        result.optVal = none(CandidValue)
      elif hasValue == 1:
        let innerValue = decodeValue(data, offset, typeEntry.optInnerType, typeTable)
        result.optVal = some(innerValue)
      else:
        raise newException(CandidDecodeError, "Invalid optional tag: " & $hasValue)
    of ctVec:
      # Vec/Blob unified processing: treat vec nat8 and blob as the same internal representation
      let elementCount = decodeULEB128(data, offset)
      
      # If element type is nat8 and type is CtVec, apply unified processing
      if typeEntry.vecElementType == typeCodeFromCandidType(ctNat8):
        # Vec nat8 / Blob unified internal representation: store uniformly in vecVal
        result.vecVal = newSeq[CandidValue](int(elementCount))
        for i in 0..<int(elementCount):
          if offset >= data.len:
            raise newException(CandidDecodeError, "Unexpected end of data in vec")
          # Store nat8 value as CandidValue
          result.vecVal[i] = CandidValue(kind: ctNat8, nat8Val: uint8(data[offset]))
          offset += 1
      else:
        # Normal vec processing (non-nat8 elements)
        result.vecVal = newSeq[CandidValue](int(elementCount))
        for i in 0..<int(elementCount):
          result.vecVal[i] = decodeValue(data, offset, typeEntry.vecElementType, typeTable)
    
    of ctBlob:
      # Vec/Blob unified processing: ctBlob case also processed uniformly as vec nat8
      let elementCount = decodeULEB128(data, offset)
      # Blob also stored uniformly in vecVal (converted appropriately by getBlob() later)
      var blobVec = newSeq[CandidValue](int(elementCount))
      for i in 0..<int(elementCount):
        if offset >= data.len:
          raise newException(CandidDecodeError, "Unexpected end of data in blob")
        # Store nat8 value as CandidValue
        blobVec[i] = CandidValue(kind: ctNat8, nat8Val: uint8(data[offset]))
        offset += 1
      result = CandidValue(kind: ctVec, vecVal: blobVec)  # Internally processed as vec
    of ctFunc:
      # Function reference: principal + method name
      # Extract function signature from type table
      var funcArgs: seq[CandidType] = @[]
      var funcReturns: Option[CandidType] = none(CandidType)
      var funcAnnotations: seq[string] = @[]
      
      # Convert type references to CandidType
      for argTypeRef in typeEntry.funcArgs:
        if argTypeRef < 0:
          funcArgs.add(typeCodeToCandidType(argTypeRef))
        else:
          funcArgs.add(ctEmpty)
      
      # Handle single return type
      if typeEntry.funcReturns.len > 0:
        let retTypeRef = typeEntry.funcReturns[0]
        if retTypeRef < 0:
          funcReturns = some(typeCodeToCandidType(retTypeRef))
        else:
          funcReturns = some(ctEmpty)
      
      # Convert annotation bytes to strings
      for annByte in typeEntry.funcAnnotations:
        case annByte:
        of 0x01: funcAnnotations.add("query")
        of 0x02: funcAnnotations.add("oneway")
        of 0x03: funcAnnotations.add("composite_query")
        else: discard
      
      var principal: Principal
      var methodName: string
      
      # Function format: ID form principal format
      # [ID form byte 0x01] [principal_bytes] [metadata or method]
      
      # Check for ID form marker
      if offset >= data.len or data[offset] != 1.byte:
        raise newException(CandidDecodeError, "Expected ID form byte in function value")
      inc offset
      
      # Decode principal
      let principalLength = decodeULEB128(data, offset)
      if principalLength < 0 or principalLength > 100:
        raise newException(CandidDecodeError, "Principal length out of range")
      if offset + int(principalLength) > data.len:
        raise newException(CandidDecodeError, "Insufficient data for principal")
      let principalBytes = data[offset ..< offset + int(principalLength)]
      principal = Principal.fromBlob(principalBytes)
      offset += int(principalLength)
      
      # Function value can be in two formats:
      # 1. Nim format: [ID=0x01][principal_len][principal][method_len][method]
      # 2. Motoko format: [ID=0x01][principal_len][principal][metadata...][method_len][method]
      #
      # The key difference is metadata after principal in Motoko format
      # Strategy: Try Nim format first (simpler), fall back to Motoko if needed
      
      var found = false
      
      # Try Nim format first - immediate method length after principal
      var testOffset = offset
      let immediateLen = decodeULEB128(data, testOffset)
      
      if immediateLen >= 0 and immediateLen <= 1000 and
         testOffset + int(immediateLen) <= data.len:
        # Verify it's likely valid text
        var isValidText = true
        if immediateLen > 0:
          for i in 0..<int(immediateLen):
            let b = data[testOffset + i]
            if b == 0:
              isValidText = false
              break
        
        if isValidText or immediateLen == 0:
          # Nim format succeeded
          if immediateLen == 0:
            methodName = ""
          else:
            methodName = newString(int(immediateLen))
            for i in 0..<int(immediateLen):
              methodName[i] = char(data[testOffset + i])
          offset = testOffset + int(immediateLen)
          found = true
      
      # If Nim format didn't work, try Motoko format (search backward from end)
      if not found:
        # Search backward from end of message
        for textLen in countdown(min(1000, data.len - offset), 1, 1):
          let textEnd = data.len - textLen
          if textEnd < offset:
            break
          
          # Try to find length byte(s) before this text
          for lenOffset in countdown(textEnd - 1, offset, 1):
            var peekOffset = lenOffset
            let potentialLen = decodeULEB128(data, peekOffset)
            
            if int(potentialLen) == textLen and
               peekOffset + textLen == data.len:
              # Found matching length that ends at end of data
              var isValidText = true
              for i in 0..<textLen:
                let b = data[peekOffset + i]
                if b == 0:
                  isValidText = false
                  break
              
              if isValidText or textLen == 0:
                if textLen == 0:
                  methodName = ""
                else:
                  methodName = newString(textLen)
                  for i in 0..<textLen:
                    methodName[i] = char(data[peekOffset + i])
                offset = peekOffset + textLen
                found = true
                break
          
          if found:
            break
      
      if not found:
        raise newException(CandidDecodeError, "Could not find valid method name in function value")
      
      result.funcVal = IcFunc(
        principal: principal,
        methodName: methodName,
        args: funcArgs,
        returns: funcReturns,
        annotations: funcAnnotations
      )
    of ctService:
      # Service reference: principal only
      let principalLength = decodeULEB128(data, offset)
      if offset + int(principalLength) > data.len:
        raise newException(CandidDecodeError, "Unexpected end of data")
      let principalBytes = data[offset..<offset + int(principalLength)]
      result.serviceVal = Principal.fromBlob(principalBytes)
      offset += int(principalLength)
    else:
      raise newException(CandidDecodeError, "Unexpected composite type: " & $typeEntry.kind)
  
  ## Decodes a value
  if typeRef < 0:
    # Primitive type
    let candidType = typeCodeToCandidType(typeRef)
    return decodePrimitiveValue(data, offset, candidType)
  else:
    # Composite type (type table reference)
    if typeRef >= typeTable.len:
      raise newException(CandidDecodeError, "Invalid type table reference: " & $typeRef)
    
    let typeEntry = typeTable[typeRef]
    return decodeCompositeValue(data, offset, typeEntry, typeTable)

# ================================================================================
# Public Procedures
# ================================================================================
proc `$`*(decodeResult: CandidDecodeResult): string =
  ## Converts CandidDecodeResult to a string
  result = "CandidDecodeResult(\n"
  result.add("  typeTable: [")
  for i, typeEntry in decodeResult.typeTable:
    if i > 0:
      result.add(", ")
    result.add($typeEntry)
  result.add("],\n")
  result.add("  values: [")
  for i, value in decodeResult.values:
    if i > 0:
      result.add(", ")
    result.add($value)
  result.add("]\n)")


proc decodeCandidMessage*(data: seq[byte]): CandidDecodeResult =
  ## Decodes a Candid message
  var offset = 0
  
  # 1. Check magic header
  if data.len < 4:
    raise newException(CandidDecodeError, "Message too short")
  
  if data[0..3] != magicHeader:
    raise newException(CandidDecodeError, "Invalid magic header")
  
  offset = 4
  
  # 2. Decode type table
  let typeTableSize = decodeULEB128(data, offset)
  var typeTable = newSeq[TypeTableEntry](int(typeTableSize))
  
  for i in 0..<int(typeTableSize):
    typeTable[i] = decodeTypeTableEntry(data, offset)
  
  # 3. Decode type sequence
  let valueCount = decodeULEB128(data, offset)
  var valueTypes = newSeq[int](int(valueCount))
  
  for i in 0..<int(valueCount):
    valueTypes[i] = decodeSLEB128(data, offset)
  
  # 4. Decode value sequence
  var values = newSeq[CandidValue](int(valueCount))
  for i in 0..<int(valueCount):
    values[i] = decodeValue(data, offset, valueTypes[i], typeTable)
  
  # 5. Check if all data has been consumed
  if offset != data.len:
    raise newException(CandidDecodeError, "Unexpected data at end of message")
  
  return CandidDecodeResult(
    typeTable: typeTable,
    values: values
  )
