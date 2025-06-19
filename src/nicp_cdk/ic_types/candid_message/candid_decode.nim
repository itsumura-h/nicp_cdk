import std/endians
import std/sequtils
import std/options
import std/algorithm
import std/tables
import ../../algorithm/leb128
import ../consts
import ../candid_types
import ../ic_principal
import ./candid_message_types


#---- 型タグバイトを CandidType に変換 ----
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
  ## 型コードをCandidTypeに変換する
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
  ## 型テーブルエントリをデコードする
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
    # フィールドをハッシュ順でソート
    result.recordFields.sort(proc(a, b: tuple[hash: uint32, fieldType: int]): int = 
      cmp(a.hash, b.hash))
  
  of ctVariant:
    let fieldCount = decodeULEB128(data, offset)
    result.variantFields = newSeq[tuple[hash: uint32, fieldType: int]](int(fieldCount))
    for i in 0..<int(fieldCount):
      let hash = uint32(decodeULEB128(data, offset))
      let fieldType = decodeSLEB128(data, offset)
      result.variantFields[i] = (hash: hash, fieldType: fieldType)
    # フィールドをハッシュ順でソート
    result.variantFields.sort(proc(a, b: tuple[hash: uint32, fieldType: int]): int = 
      cmp(a.hash, b.hash))
  
  of ctOpt:
    result.optInnerType = decodeSLEB128(data, offset)
  
  of ctVec:
    result.vecElementType = decodeSLEB128(data, offset)
  
  of ctBlob:
    # Blobはvec nat8として処理されるが、要素型は確認のみ
    let elementType = decodeSLEB128(data, offset)
    # nat8でない場合はエラー（実際にはBlob専用の処理ではないが、一貫性のため）
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
    # メソッドをハッシュ順でソート
    result.serviceMethods.sort(proc(a, b: tuple[hash: uint32, methodType: int]): int = 
      cmp(a.hash, b.hash))
  
  else:
    discard


proc decodePrimitiveValue(data: seq[byte], offset: var int, candidType: CandidType): CandidValue =
  ## 基本型の値をデコードする
  result = CandidValue(kind: candidType)
  
  case candidType:
  of ctNull:
    discard  # nullは値を持たない
  
  of ctBool:
    if offset >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    result.boolVal = data[offset] != 0
    inc offset
  
  of ctNat:
    result.natVal = uint(decodeULEB128(data, offset))
  
  of ctInt:
    result.intVal = decodeSLEB128(data, offset)
  
  of ctNat8:
    if offset >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    result.natVal = uint(data[offset])
    inc offset
  
  of ctNat16:
    if offset + 1 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: uint16
    littleEndian16(addr val, unsafeAddr data[offset])
    result.natVal = uint(val)
    offset += 2
  
  of ctNat32:
    if offset + 3 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: uint32
    littleEndian32(addr val, unsafeAddr data[offset])
    result.natVal = uint(val)
    offset += 4
  
  of ctNat64:
    if offset + 7 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: uint64
    littleEndian64(addr val, unsafeAddr data[offset])
    result.natVal = uint(val)
    offset += 8
  
  of ctInt8:
    if offset >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    result.intVal = int(cast[int8](data[offset]))
    inc offset
  
  of ctInt16:
    if offset + 1 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: int16
    littleEndian16(addr val, unsafeAddr data[offset])
    result.intVal = int(val)
    offset += 2
  
  of ctInt32:
    if offset + 3 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: int32
    littleEndian32(addr val, unsafeAddr data[offset])
    result.intVal = int(val)
    offset += 4
  
  of ctInt64:
    if offset + 7 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: int64
    littleEndian64(addr val, unsafeAddr data[offset])
    result.intVal = int(val)
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
    # IDフォーム識別子をスキップ（値は1のはず）
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
    # reservedは値を無視する
    discard
  
  of ctEmpty:
    # emptyは値を持たない（何もしない）
    discard
  
  else:
    raise newException(CandidDecodeError, "Unexpected primitive type: " & $candidType)


proc decodeValue(data: seq[byte], offset: var int, typeRef: int, typeTable: seq[TypeTableEntry]): CandidValue =
  proc decodeCompositeValue(data: seq[byte], offset: var int, typeEntry: TypeTableEntry, typeTable: seq[TypeTableEntry]): CandidValue =
    ## 複合型の値をデコードする
    result = CandidValue(kind: typeEntry.kind)
    case typeEntry.kind:
    of ctRecord:
      result.recordVal = CandidRecord(kind: ckRecord, fields: initOrderedTable[string, CandidValue]())
      # フィールドは型テーブルで定義された順序で値が並んでいる
      for fieldInfo in typeEntry.recordFields:
        let fieldValue = decodeValue(data, offset, fieldInfo.fieldType, typeTable)
        # ハッシュ値をフィールド名として使用（実際の実装では名前の逆引きが必要）
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
      # Vec/Blob統一処理: vec nat8とblobを同一内部表現として処理
      let elementCount = decodeULEB128(data, offset)
      
      # 要素型がnat8かつ、型がCtVecの場合は統一処理
      if typeEntry.vecElementType == typeCodeFromCandidType(ctNat8):
        # Vec nat8 / Blob 統一内部表現: vecValに統一的に格納
        result.vecVal = newSeq[CandidValue](int(elementCount))
        for i in 0..<int(elementCount):
          if offset >= data.len:
            raise newException(CandidDecodeError, "Unexpected end of data in vec")
          # nat8値をCandidValueとして格納
          result.vecVal[i] = CandidValue(kind: ctNat8, natVal: uint(data[offset]))
          offset += 1
      else:
        # 通常のvec処理（非nat8要素）
        result.vecVal = newSeq[CandidValue](int(elementCount))
        for i in 0..<int(elementCount):
          result.vecVal[i] = decodeValue(data, offset, typeEntry.vecElementType, typeTable)
    
    of ctBlob:
      # Vec/Blob統一処理: ctBlobケースもvec nat8として統一処理
      let elementCount = decodeULEB128(data, offset)
      # blobもvecValに統一的に格納（後でgetBlob()で適切に変換）
      result.kind = ctVec  # 内部的にはvecとして処理
      result.vecVal = newSeq[CandidValue](int(elementCount))
      for i in 0..<int(elementCount):
        if offset >= data.len:
          raise newException(CandidDecodeError, "Unexpected end of data in blob")
        # nat8値をCandidValueとして格納
        result.vecVal[i] = CandidValue(kind: ctNat8, natVal: uint(data[offset]))
        offset += 1
    of ctFunc:
      # 関数参照: principal + method name
      let principalLength = decodeULEB128(data, offset)
      if offset + int(principalLength) > data.len:
        raise newException(CandidDecodeError, "Unexpected end of data")
      let principalBytes = data[offset..<offset + int(principalLength)]
      let principal = Principal.fromBlob(principalBytes)
      offset += int(principalLength)
      
      let methodNameLength = decodeULEB128(data, offset)
      if offset + int(methodNameLength) > data.len:
        raise newException(CandidDecodeError, "Unexpected end of data")
      var methodName = newString(int(methodNameLength))
      for i in 0..<int(methodNameLength):
        methodName[i] = char(data[offset + i])
      offset += int(methodNameLength)
      
      let funcRef = CandidFunc(
        principal: principal,
        methodName: methodName,
        args: @[],
        returns: @[],
        annotations: @[]
      )
      result.funcVal = funcRef
    of ctService:
      # サービス参照: principal のみ
      let principalLength = decodeULEB128(data, offset)
      if offset + int(principalLength) > data.len:
        raise newException(CandidDecodeError, "Unexpected end of data")
      let principalBytes = data[offset..<offset + int(principalLength)]
      result.serviceVal = Principal.fromBlob(principalBytes)
      offset += int(principalLength)
    else:
      raise newException(CandidDecodeError, "Unexpected composite type: " & $typeEntry.kind)
  
  ## 値をデコードする
  if typeRef < 0:
    # 基本型
    let candidType = typeCodeToCandidType(typeRef)
    return decodePrimitiveValue(data, offset, candidType)
  else:
    # 複合型（型テーブル参照）
    if typeRef >= typeTable.len:
      raise newException(CandidDecodeError, "Invalid type table reference: " & $typeRef)
    
    let typeEntry = typeTable[typeRef]
    return decodeCompositeValue(data, offset, typeEntry, typeTable)

# ================================================================================
# Public Procedures
# ================================================================================
proc `$`*(decodeResult: CandidDecodeResult): string =
  ## CandidDecodeResult を文字列に変換する
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
  ## Candidメッセージをデコードする
  var offset = 0
  
  # 1. 魔法数の確認
  if data.len < 4:
    raise newException(CandidDecodeError, "Message too short")
  
  if data[0..3] != magicHeader:
    raise newException(CandidDecodeError, "Invalid magic header")
  
  offset = 4
  
  # 2. 型テーブルのデコード
  let typeTableSize = decodeULEB128(data, offset)
  var typeTable = newSeq[TypeTableEntry](int(typeTableSize))
  
  for i in 0..<int(typeTableSize):
    typeTable[i] = decodeTypeTableEntry(data, offset)
  
  # 3. 型シーケンスのデコード
  let valueCount = decodeULEB128(data, offset)
  var valueTypes = newSeq[int](int(valueCount))
  
  for i in 0..<int(valueCount):
    valueTypes[i] = decodeSLEB128(data, offset)
  
  # 4. 値シーケンスのデコード
  var values = newSeq[CandidValue](int(valueCount))
  for i in 0..<int(valueCount):
    values[i] = decodeValue(data, offset, valueTypes[i], typeTable)
  
  # 5. 全データが消費されたかチェック
  if offset != data.len:
    raise newException(CandidDecodeError, "Unexpected data at end of message")
  
  return CandidDecodeResult(
    typeTable: typeTable,
    values: values
  )
