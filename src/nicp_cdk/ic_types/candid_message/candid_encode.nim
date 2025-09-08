import std/endians
import std/sequtils
import std/tables
import std/algorithm
import std/options
import ../../algorithm/leb128
import ../candid_types
import ../consts
import ../ic_principal
import ./candid_message_types


# ================================================================================
# Private Procedures
# ================================================================================
proc getTypeSignature(typeDesc: TypeDescriptor): string =
  ## Generates a unique string representation of the type (for deduplication)
  case typeDesc.kind:
  of ctRecord:
    result = "record{"
    var sortedFields = typeDesc.recordFields
    sortedFields.sort(proc(a, b: tuple[hash: uint32, fieldType: TypeDescriptor]): int = 
      cmp(a.hash, b.hash))
    for field in sortedFields:
      result.add($field.hash & ":" & getTypeSignature(field.fieldType) & ";")
    result.add("}")
  of ctVariant:
    result = "variant{"
    var sortedFields = typeDesc.variantFields
    sortedFields.sort(proc(a, b: tuple[hash: uint32, fieldType: TypeDescriptor]): int = 
      cmp(a.hash, b.hash))
    for field in sortedFields:
      result.add($field.hash & ":" & getTypeSignature(field.fieldType) & ";")
    result.add("}")
  of ctOpt:
    result = "opt(" & getTypeSignature(typeDesc.optInnerType) & ")"
  of ctVec:
    result = "vec(" & getTypeSignature(typeDesc.vecElementType) & ")"
  of ctFunc:
    result = "func("
    for arg in typeDesc.funcArgs:
      result.add(getTypeSignature(arg) & ",")
    result.add(")->{")
    for ret in typeDesc.funcReturns:
      result.add(getTypeSignature(ret) & ",")
    result.add("}")
  of ctService:
    result = "service{"
    var sortedMethods = typeDesc.serviceMethods
    sortedMethods.sort(proc(a, b: tuple[hash: uint32, methodType: TypeDescriptor]): int = 
      cmp(a.hash, b.hash))
    for rowMethod in sortedMethods:
      result.add($rowMethod.hash & ":" & getTypeSignature(rowMethod.methodType) & ";")
    result.add("}")
  else:
    # Fallback for primitive or unprocessed types
    result = $typeDesc.kind


proc inferTypeDescriptor(value: CandidValue): TypeDescriptor =
  ## Infers type descriptor from CandidValue
  result = TypeDescriptor(kind: value.kind)
  case value.kind:
  of ctRecord:
    result.recordFields = @[]
    for fieldName, fieldValue in value.recordVal.fields:
      # Calculate hash value from field name
      let fieldHash = candidHash(fieldName)
      result.recordFields.add((hash: fieldHash, fieldType: inferTypeDescriptor(fieldValue)))
  of ctVariant:
    # For variants, infer type only from the selected tag
    result.variantFields = @[(hash: value.variantVal.tag, fieldType: inferTypeDescriptor(value.variantVal.value))]
  of ctOpt:
    if value.optVal.isSome:
      result.optInnerType = inferTypeDescriptor(value.optVal.get())
    else:
      # None の場合でも、エンコーダが保持する型ヒントがあればそれを使う
      if value.optInnerHint.isSome:
        result.optInnerType = TypeDescriptor(kind: value.optInnerHint.get())
      else:
        # 型ヒントが無ければ暫定的にnullとして扱う（互換保持）
        result.optInnerType = TypeDescriptor(kind: ctNull)
  of ctVec:
    if value.vecVal.len > 0:
      let firstElement = value.vecVal[0]
      if firstElement.kind == ctBlob:
        # For vec blob, elements are blob type (treated as vec nat8)
        result.vecElementType = TypeDescriptor(kind: ctVec, vecElementType: TypeDescriptor(kind: ctNat8))
      else:
        result.vecElementType = inferTypeDescriptor(firstElement)
    else:
      # If empty vector, element type cannot be inferred, so assume empty
      result.vecElementType = TypeDescriptor(kind: ctEmpty)
  of ctBlob:
    # Blob is always processed as vec nat8
    discard
  of ctFunc:
    # Build function type descriptor from value.funcVal metadata
    result.funcArgs = @[]
    for argCt in value.funcVal.args:
      # Only primitive kinds are supported directly here; others may require richer descriptors
      result.funcArgs.add(TypeDescriptor(kind: argCt))
    result.funcReturns = @[]
    if value.funcVal.returns.isSome:
      result.funcReturns.add(TypeDescriptor(kind: value.funcVal.returns.get))
    # Encode annotations as bytes per spec
    result.funcAnnotations = @[]
    for ann in value.funcVal.annotations:
      case ann
      of "query": result.funcAnnotations.add(0x01'u8)
      of "oneway": result.funcAnnotations.add(0x02'u8)
      of "composite_query": result.funcAnnotations.add(0x03'u8)
      else: discard
  else:
    discard


proc addTypeToTable(builder: var TypeBuilder, typeDesc: TypeDescriptor): int =
  ## Adds type to table and returns index (with duplicate check)
  let signature = getTypeSignature(typeDesc)
  if signature in builder.typeIndexMap:
    return builder.typeIndexMap[signature]
  
  # Create new type entry
  let newIndex = builder.typeTable.len
  builder.typeIndexMap[signature] = newIndex
  
  # First, add empty entry to ensure index
  var entry = TypeTableEntry(kind: typeDesc.kind)
  builder.typeTable.add(entry)
  
  # Then, set details
  entry = TypeTableEntry(kind: typeDesc.kind)
  
  case typeDesc.kind:
  of ctRecord:
    entry.recordFields = @[]
    var sortedFields = typeDesc.recordFields
    sortedFields.sort(proc(a, b: tuple[hash: uint32, fieldType: TypeDescriptor]): int = 
      cmp(a.hash, b.hash))
    for field in sortedFields:
      let fieldTypeRef =
        if isPrimitiveType(field.fieldType.kind):
          typeCodeFromCandidType(field.fieldType.kind)
        else:
          addTypeToTable(builder, field.fieldType)
      entry.recordFields.add((hash: field.hash, fieldType: fieldTypeRef))
  
  of ctVariant:
    entry.variantFields = @[]
    var sortedFields = typeDesc.variantFields
    sortedFields.sort(proc(a, b: tuple[hash: uint32, fieldType: TypeDescriptor]): int = 
      cmp(a.hash, b.hash))
    for field in sortedFields:
      let fieldTypeRef = if isPrimitiveType(field.fieldType.kind):
        typeCodeFromCandidType(field.fieldType.kind)
      else:
        addTypeToTable(builder, field.fieldType)
      entry.variantFields.add((hash: field.hash, fieldType: fieldTypeRef))
  
  of ctOpt:
    entry.optInnerType = if isPrimitiveType(typeDesc.optInnerType.kind):
      typeCodeFromCandidType(typeDesc.optInnerType.kind)
    else:
      addTypeToTable(builder, typeDesc.optInnerType)
  
  of ctVec:
    entry.vecElementType = if isPrimitiveType(typeDesc.vecElementType.kind):
      typeCodeFromCandidType(typeDesc.vecElementType.kind)
    else:
      addTypeToTable(builder, typeDesc.vecElementType)
  
  of ctBlob:
    # Blob is processed as vec nat8
    discard
  
  of ctFunc:
    entry.funcArgs = @[]
    for arg in typeDesc.funcArgs:
      let argTypeRef = if isPrimitiveType(arg.kind):
        typeCodeFromCandidType(arg.kind)
      else:
        addTypeToTable(builder, arg)
      entry.funcArgs.add(argTypeRef)
    
    entry.funcReturns = @[]
    for ret in typeDesc.funcReturns:
      let retTypeRef = if isPrimitiveType(ret.kind):
        typeCodeFromCandidType(ret.kind)
      else:
        addTypeToTable(builder, ret)
      entry.funcReturns.add(retTypeRef)
    
    entry.funcAnnotations = typeDesc.funcAnnotations
  
  of ctService:
    entry.serviceMethods = @[]
    var sortedMethods = typeDesc.serviceMethods
    sortedMethods.sort(proc(a, b: tuple[hash: uint32, methodType: TypeDescriptor]): int = 
      cmp(a.hash, b.hash))
    for rowMethod in sortedMethods:
      let methodTypeRef = addTypeToTable(builder, rowMethod.methodType)
      entry.serviceMethods.add((hash: rowMethod.hash, methodType: methodTypeRef))
  
  else:
    discard
  
  # Update entry details
  builder.typeTable[newIndex] = entry
  return newIndex


proc encodeTypeTableEntry(entry: TypeTableEntry): seq[byte] =
  ## Encodes type table entry
  result = @[]
  
  # Encode type code with SLEB128
  let typeCode = typeCodeFromCandidType(entry.kind)
  result.add(encodeSLEB128(int32(typeCode)))
  
  case entry.kind:
  of ctRecord:
    result.add(encodeULEB128(uint(entry.recordFields.len)))
    for field in entry.recordFields:
      result.add(encodeULEB128(field.hash))
      result.add(encodeSLEB128(int32(field.fieldType)))
  
  of ctVariant:
    result.add(encodeULEB128(uint(entry.variantFields.len)))
    for field in entry.variantFields:
      result.add(encodeULEB128(field.hash))
      result.add(encodeSLEB128(int32(field.fieldType)))
  
  of ctOpt:
    result.add(encodeSLEB128(int32(entry.optInnerType)))
  
  of ctVec:
    result.add(encodeSLEB128(int32(entry.vecElementType)))
  
  of ctBlob:
    # Blob is processed as vec nat8, so output nat8 type code
    result.add(encodeSLEB128(int32(typeCodeFromCandidType(ctNat8))))
  
  of ctFunc:
    result.add(encodeULEB128(uint(entry.funcArgs.len)))
    for arg in entry.funcArgs:
      result.add(encodeSLEB128(int32(arg)))
    
    result.add(encodeULEB128(uint(entry.funcReturns.len)))
    for ret in entry.funcReturns:
      result.add(encodeSLEB128(int32(ret)))
    
    result.add(encodeULEB128(uint(entry.funcAnnotations.len)))
    result.add(entry.funcAnnotations)
  
  of ctService:
    result.add(encodeULEB128(uint(entry.serviceMethods.len)))
    for rowMethod in entry.serviceMethods:
      result.add(encodeULEB128(rowMethod.hash))
      result.add(encodeSLEB128(int32(rowMethod.methodType)))
  
  else:
    discard


proc encodePrimitiveValue(value: CandidValue): seq[byte] =
  ## Encodes value of primitive type
  result = @[]
  
  case value.kind:
  of ctNull:
    discard  # null has no value
  
  of ctBool:
    result.add(if value.boolVal: byte(1) else: byte(0))
  
  of ctNat:
    result.add(encodeULEB128(uint(value.natVal)))
  
  of ctInt:
    result.add(encodeSLEB128(int32(value.intVal)))
  
  of ctNat8:
    result.add(value.nat8Val)
  
  of ctNat16:
    var val = value.nat16Val
    result.setLen(2)
    littleEndian16(addr result[0], addr val)
  
  of ctNat32:
    var val = value.nat32Val
    result.setLen(4)
    littleEndian32(addr result[0], addr val)
  
  of ctNat64:
    var val = value.nat64Val
    result.setLen(8)
    littleEndian64(addr result[0], addr val)
  
  of ctInt8:
    result.add(byte(value.int8Val))
  
  of ctInt16:
    var val = value.int16Val
    result.setLen(2)
    littleEndian16(addr result[0], addr val)
  
  of ctInt32:
    var val = value.int32Val
    result.setLen(4)
    littleEndian32(addr result[0], addr val)
  
  of ctInt64:
    var val = value.int64Val
    result.setLen(8)
    littleEndian64(addr result[0], addr val)
  
  of ctFloat:
    # float is treated as float32
    result.setLen(4)
    var float32Val = float32(value.floatVal)
    littleEndian32(addr result[0], unsafeAddr float32Val)
  
  of ctFloat32:
    result.setLen(4)
    littleEndian32(addr result[0], unsafeAddr value.float32Val)
  
  of ctFloat64:
    result.setLen(8)
    littleEndian64(addr result[0], unsafeAddr value.float64Val)
  
  of ctText:
    let textBytes = cast[seq[byte]](value.textVal)
    result.add(encodeULEB128(uint(textBytes.len)))
    result.add(textBytes)
  
  of ctPrincipal:
    let principalBytes = value.principalVal.bytes
    result.add(1.byte) # ID form identifier
    result.add(encodeULEB128(uint(principalBytes.len)))
    result.add(principalBytes)
  
  of ctBlob:
    # Blob is processed as vec nat8
    result.add(encodeULEB128(uint(value.blobVal.len)))
    for byteVal in value.blobVal:
      result.add(byteVal)
  
  of ctReserved:
    discard  # reserved has no value
  
  of ctEmpty:
    discard  # empty has no value
  
  else:
    raise newException(ValueError, "Not a primitive type: " & $value.kind)


proc encodeValue(value: CandidValue, typeRef: int, typeTable: seq[TypeTableEntry]): seq[byte] =
  ## Encodes value (both primitive and composite types)
  result = @[]
  
  if typeRef < 0:
    # Primitive type
    result.add(encodePrimitiveValue(value))
  else:
    # Composite type
    let typeEntry = typeTable[typeRef]
    case typeEntry.kind:
    of ctRecord:
      # Encode each field of record in order of type table
      for fieldInfo in typeEntry.recordFields:
        var foundField: bool = false
        var fieldValue: CandidValue
        
        # Search for field in record (compare by field name hash)
        for fieldName, fieldVal in value.recordVal.fields:
          if candidHash(fieldName) == fieldInfo.hash:
            foundField = true
            fieldValue = fieldVal
            break
        
        if foundField:
          result.add(encodeValue(fieldValue, fieldInfo.fieldType, typeTable))
        else:
          raise newException(ValueError, "Missing field in record: " & $fieldInfo.hash)
    
    of ctVariant:
      # Check value type before accessing variantVal
      if value.kind == ctVariant:
        # Find index of selected tag
        var tagIndex = -1
        for i, fieldInfo in typeEntry.variantFields:
          if fieldInfo.hash == value.variantVal.tag:
            tagIndex = i
            break
        
        if tagIndex == -1:
          raise newException(ValueError, "Invalid variant tag: " & $value.variantVal.tag)
        
        result.add(encodeULEB128(uint(tagIndex)))
        result.add(encodeValue(value.variantVal.value, typeEntry.variantFields[tagIndex].fieldType, typeTable))
      else:
        raise newException(ValueError, "Type mismatch: expected variant value but got " & $value.kind & 
                          ". TypeRef: " & $typeRef & ", TypeEntry: " & $typeEntry.kind)
    
    of ctOpt:
      if value.optVal.isSome:
        result.add(encodeULEB128(1))  # has value
        result.add(encodeValue(value.optVal.get(), typeEntry.optInnerType, typeTable))
      else:
        result.add(encodeULEB128(0))  # no value
    
    of ctVec:
      if value.kind == ctBlob:
        # Special case for ctBlob (processed as vec nat8)
        result.add(encodeULEB128(uint(value.blobVal.len)))
        for byteVal in value.blobVal:
          result.add(byteVal)
      else:
        # Normal vec processing
        result.add(encodeULEB128(uint(value.vecVal.len)))
        for element in value.vecVal:
          result.add(encodeValue(element, typeEntry.vecElementType, typeTable))
    
    of ctBlob:
      # Special case for ctBlob - necessary for vec blob processing
      result.add(encodeULEB128(uint(value.blobVal.len)))
      for byteVal in value.blobVal:
        result.add(byteVal)
    
    of ctFunc:
      # Function reference: ID form + principal + method name
      # Use same format as principal (ID form 0x01)
      result.add(1.byte)  # ID form identifier
      let principalBytes = value.funcVal.principal.bytes
      result.add(encodeULEB128(uint(principalBytes.len)))
      result.add(principalBytes)
      
      let methodNameBytes = cast[seq[byte]](value.funcVal.methodName)
      result.add(encodeULEB128(uint(methodNameBytes.len)))
      result.add(methodNameBytes)
    
    of ctService:
      # Service reference: only principal
      let principalBytes = value.serviceVal.bytes
      result.add(encodeULEB128(uint(principalBytes.len)))
      result.add(principalBytes)
    
    else:
      raise newException(ValueError, "Unsupported composite type for encoding: " & $typeEntry.kind)


# ================================================================================
# Public Procedures
# ================================================================================
proc encodeCandidMessage*(values: seq[CandidValue]): seq[byte] =
  ## Encodes Candid message
  result = @[]
  
  # 1. Add magic number
  result.add(magicHeader)
 
  # 2. Build type table
  var builder = TypeBuilder(
    typeTable: @[],
    typeIndexMap: initTable[string, int]()
  )

  var valueTypes: seq[int] = @[]
  # Analyze each value and add to type table
  for value in values:
    var typeRef: int
    if value.kind == ctBlob:
      # Add vec type to type table as non-primitive (used as composite type)
      let vecTypeDesc = TypeDescriptor(kind: ctVec, vecElementType: TypeDescriptor(kind: ctNat8))
      typeRef = addTypeToTable(builder, vecTypeDesc)
    elif value.kind == ctVec and value.vecVal.len > 0 and value.vecVal[0].kind == ctBlob:
      # Special processing for vec blob (seq[seq[uint8]])
      let blobTypeDesc = TypeDescriptor(kind: ctVec, vecElementType: TypeDescriptor(kind: ctNat8))
      let vecBlobTypeDesc = TypeDescriptor(kind: ctVec, vecElementType: blobTypeDesc)
      typeRef = addTypeToTable(builder, vecBlobTypeDesc)
    elif isPrimitiveType(value.kind):
      typeRef = typeCodeFromCandidType(value.kind)
    else:
      let typeDesc = inferTypeDescriptor(value)
      typeRef = addTypeToTable(builder, typeDesc)
    valueTypes.add(typeRef)
  
  # 3. Encode type table
  result.add(encodeULEB128(uint(builder.typeTable.len)))
  for entry in builder.typeTable:
    result.add(encodeTypeTableEntry(entry))

  # 4. Encode type sequence
  result.add(encodeULEB128(uint(valueTypes.len)))
  for typeRef in valueTypes:
    result.add(encodeSLEB128(int32(typeRef)))
  
  # 5. Encode value sequence
  for i, value in values:
    result.add(encodeValue(value, valueTypes[i], builder.typeTable))
