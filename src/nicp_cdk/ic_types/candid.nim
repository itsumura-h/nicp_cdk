import std/endians
import std/sequtils
import std/strutils
import std/tables
import std/options
import std/algorithm
import ../algorithm/leb128
import ./ic_principal
import ./ic_text
import ./consts


proc toString*(data: seq[byte]): string =
  return data.mapIt(it.toHex()).join("")


proc stringToBytes*(s: string): seq[byte] =
  # 2文字ずつバイト列に変換
  for i in countup(0, s.len-1, 2):
    result.add(byte(s[i..i+1].parseHexInt()))


# Candid型定義
# https://github.com/dfinity/candid/blob/master/spec/Candid.md#types
#[

T(null)      = sleb128(-1)  = 0x7f
T(bool)      = sleb128(-2)  = 0x7e
T(nat)       = sleb128(-3)  = 0x7d
T(int)       = sleb128(-4)  = 0x7c
T(nat8)      = sleb128(-5)  = 0x7b
T(nat16)     = sleb128(-6)  = 0x7a
T(nat32)     = sleb128(-7)  = 0x79
T(nat64)     = sleb128(-8)  = 0x78
T(int8)      = sleb128(-9)  = 0x77
T(int16)     = sleb128(-10) = 0x76
T(int32)     = sleb128(-11) = 0x75
T(int64)     = sleb128(-12) = 0x74
T(float32)   = sleb128(-13) = 0x73
T(float64)   = sleb128(-14) = 0x72
T(text)      = sleb128(-15) = 0x71
T(reserved)  = sleb128(-16) = 0x70
T(empty)     = sleb128(-17) = 0x6f
T(principal) = sleb128(-24) = 0x68

T(opt <datatype>) = sleb128(-18) I(<datatype>)              // 0x6e
T(vec <datatype>) = sleb128(-19) I(<datatype>)              // 0x6d
T(record {<fieldtype>^N}) = sleb128(-20) T*(<fieldtype>^N)  // 0x6c
T(variant {<fieldtype>^N}) = sleb128(-21) T*(<fieldtype>^N) // 0x6b
]#


#---- Candid 型タグの定義 ----
type
  CandidType* = enum
    ctNull, ctBool, ctNat, ctInt,
    ctNat8, ctNat16, ctNat32, ctNat64,
    ctInt8, ctInt16, ctInt32, ctInt64,
    ctFloat32, ctFloat64,
    ctText, ctReserved, ctEmpty, ctPrincipal,
    ctRecord, ctVariant, ctOpt, ctVec,
    ctFunc, ctService, ctQuery, ctOneway, ctCompositeQuery

  # 相互参照する型を同一typeブロック内で定義
  CandidValue* = ref object
    case kind*: CandidType
    of ctNull: discard
    of ctBool: boolVal*: bool
    of ctNat,  ctNat8,  ctNat16,  ctNat32,  ctNat64: natVal*: Natural
    of ctInt,  ctInt8,  ctInt16,  ctInt32,  ctInt64: intVal*: int
    of ctFloat32: float32Val*: float32
    of ctFloat64: float64Val*: float64
    of ctText: textVal*: string
    of ctPrincipal: principalVal*: Principal
    of ctRecord: recordVal*: CandidRecord
    of ctVariant: variantVal*: CandidVariant
    of ctOpt: optVal*: Option[CandidValue]
    of ctVec: vecVal*: seq[CandidValue]
    of ctFunc: funcVal*: tuple[principal: Principal, methodName: string]
    of ctService: serviceVal*: Principal
    of ctReserved, ctEmpty: discard
    of ctQuery: discard
    of ctOneway: discard
    of ctCompositeQuery: discard

  CandidRecord* = ref object
    values*: Table[uint32, CandidValue]

  CandidVariant* = ref object
    tag*: uint32
    value*: CandidValue


proc ptrToUint32*(p: pointer): uint32 =
  return cast[uint32](p)


proc ptrToInt*(p: pointer): int =
  return cast[int](p)


#---- 型タグバイトを CandidType に変換 ----
proc parseTypeTag(b: byte): CandidType =
  ## Parse a byte and return a CandidType
  case b
  of tagNull:           ctNull # 0x7f
  of tagBool:           ctBool # 0x7e
  of tagNat:            ctNat # 0x7d
  of tagInt:            ctInt # 0x7c
  of tagNat8:           ctNat8 # 0x7b
  of tagNat16:          ctNat16 # 0x7a
  of tagNat32:          ctNat32 # 0x79
  of tagNat64:          ctNat64 # 0x78
  of tagInt8:           ctInt8 # 0x77
  of tagInt16:          ctInt16 # 0x76
  of tagInt32:          ctInt32 # 0x75
  of tagInt64:          ctInt64 # 0x74
  of tagFloat32:        ctFloat32 # 0x73
  of tagFloat64:        ctFloat64 # 0x72
  of tagText:           ctText # 0x71
  of tagReserved:       ctReserved # 0x70
  of tagEmpty:          ctEmpty # 0x6f
  of tagRecord:         ctRecord # 0x6c
  of tagVariant:        ctVariant # 0x6b
  of tagOptional:       ctOpt # 0x6e
  of tagVec:            ctVec # 0x6d
  of tagFunc:           ctFunc # 0x6a
  of tagService:        ctService # 0x69
  of tagQuery:          ctQuery # 0x01
  of tagOneway:         ctOneway # 0x02
  of tagCompositeQuery: ctCompositeQuery # 0x03
  of tagPrincipal:      ctPrincipal # 0x68
  else:
    quit("Unknown Candid tag: " & $b)


# フィールド名から32bitハッシュを計算（Candidの仕様に従う）
proc candidHash(name: string): uint32 =
  ## Candid仕様のフィールドハッシュ計算
  var h: uint32 = 0
  for c in name:
    h = h * 223 + uint32(ord(c))
  return h


# ================================================================================
# Record Type
# ================================================================================ 
proc `[]`*(r: CandidRecord, key: string): CandidValue =
  let hashedKey = candidHash(key)
  if hashedKey in r.values:
    return r.values[hashedKey]
  else:
    raise newException(KeyError, "Key not found: " & key)


proc `[]=`*(r: var CandidRecord, key: string, value: CandidValue) =
  let hashedKey = candidHash(key)
  r.values[hashedKey] = value

# Record型のフィールド情報を保持する内部型
type RecordFieldInfo = object
  hash: uint32
  fieldType: CandidType

# ================================================================================
# Candid Message Decoder
# ================================================================================

# 型テーブルエントリを表す型
type
  TypeTableEntry* = ref object
    case kind*: CandidType
    of ctRecord:
      recordFields*: seq[tuple[hash: uint32, fieldType: int]]  # int は型テーブルインデックスまたは負の型コード
    of ctVariant:
      variantFields*: seq[tuple[hash: uint32, fieldType: int]]
    of ctOpt:
      optInnerType*: int
    of ctVec:
      vecElementType*: int
    of ctFunc:
      funcArgs*: seq[int]
      funcReturns*: seq[int]
      funcAnnotations*: seq[byte]
    of ctService:
      serviceMethods*: seq[tuple[hash: uint32, methodType: int]]
    else:
      discard

# デコード結果を格納する型
type
  CandidDecodeResult* = object
    typeTable*: seq[TypeTableEntry]
    values*: seq[CandidValue]

# デコードエラー
type CandidDecodeError* = object of CatchableError


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
    result.recordFields = newSeq[tuple[hash: uint32, fieldType: int]](fieldCount)
    for i in 0..<fieldCount:
      let hash = uint32(decodeULEB128(data, offset))
      let fieldType = decodeSLEB128(data, offset)
      result.recordFields[i] = (hash: hash, fieldType: fieldType)
    # フィールドをハッシュ順でソート
    result.recordFields.sort(proc(a, b: tuple[hash: uint32, fieldType: int]): int = 
      cmp(a.hash, b.hash))
  
  of ctVariant:
    let fieldCount = decodeULEB128(data, offset)
    result.variantFields = newSeq[tuple[hash: uint32, fieldType: int]](fieldCount)
    for i in 0..<fieldCount:
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
  
  of ctFunc:
    let argCount = decodeULEB128(data, offset)
    result.funcArgs = newSeq[int](argCount)
    for i in 0..<argCount:
      result.funcArgs[i] = decodeSLEB128(data, offset)
    
    let returnCount = decodeULEB128(data, offset)
    result.funcReturns = newSeq[int](returnCount)
    for i in 0..<returnCount:
      result.funcReturns[i] = decodeSLEB128(data, offset)
    
    let annotationLength = decodeULEB128(data, offset)
    result.funcAnnotations = newSeq[byte](annotationLength)
    for i in 0..<annotationLength:
      result.funcAnnotations[i] = data[offset]
      inc offset
  
  of ctService:
    let methodCount = decodeULEB128(data, offset)
    result.serviceMethods = newSeq[tuple[hash: uint32, methodType: int]](methodCount)
    for i in 0..<methodCount:
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
    result.natVal = Natural(decodeULEB128(data, offset))
  
  of ctInt:
    result.intVal = decodeSLEB128(data, offset)
  
  of ctNat8:
    if offset >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    result.natVal = Natural(data[offset])
    inc offset
  
  of ctNat16:
    if offset + 1 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: uint16
    littleEndian16(addr val, unsafeAddr data[offset])
    result.natVal = Natural(val)
    offset += 2
  
  of ctNat32:
    if offset + 3 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: uint32
    littleEndian32(addr val, unsafeAddr data[offset])
    result.natVal = Natural(val)
    offset += 4
  
  of ctNat64:
    if offset + 7 >= data.len:
      raise newException(CandidDecodeError, "Unexpected end of data")
    var val: uint64
    littleEndian64(addr val, unsafeAddr data[offset])
    result.natVal = Natural(val)
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
    result.textVal = newString(textLength)
    for i in 0..<textLength:
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
    # emptyは値があってはならない
    raise newException(CandidDecodeError, "Empty type should not have a value")
  
  else:
    raise newException(CandidDecodeError, "Unexpected primitive type: " & $candidType)


proc decodeValue(data: seq[byte], offset: var int, typeRef: int, typeTable: seq[TypeTableEntry]): CandidValue =
  proc decodeCompositeValue(data: seq[byte], offset: var int, typeEntry: TypeTableEntry, typeTable: seq[TypeTableEntry]): CandidValue =
    ## 複合型の値をデコードする
    result = CandidValue(kind: typeEntry.kind)
    case typeEntry.kind:
    of ctRecord:
      result.recordVal = CandidRecord(values: initTable[uint32, CandidValue]())
      # フィールドは型テーブルで定義された順序で値が並んでいる
      for fieldInfo in typeEntry.recordFields:
        let fieldValue = decodeValue(data, offset, fieldInfo.fieldType, typeTable)
        result.recordVal.values[fieldInfo.hash] = fieldValue
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
      let elementCount = decodeULEB128(data, offset)
      result.vecVal = newSeq[CandidValue](elementCount)
      for i in 0..<elementCount:
        result.vecVal[i] = decodeValue(data, offset, typeEntry.vecElementType, typeTable)
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
      var methodName = newString(methodNameLength)
      for i in 0..<methodNameLength:
        methodName[i] = char(data[offset + i])
      offset += int(methodNameLength)
      
      result.funcVal = (principal: principal, methodName: methodName)
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
  var typeTable = newSeq[TypeTableEntry](typeTableSize)
  
  for i in 0..<typeTableSize:
    typeTable[i] = decodeTypeTableEntry(data, offset)
  
  # 3. 型シーケンスのデコード
  let valueCount = decodeULEB128(data, offset)
  var valueTypes = newSeq[int](valueCount)
  
  for i in 0..<valueCount:
    valueTypes[i] = decodeSLEB128(data, offset)
  
  # 4. 値シーケンスのデコード
  var values = newSeq[CandidValue](valueCount)
  for i in 0..<valueCount:
    values[i] = decodeValue(data, offset, valueTypes[i], typeTable)
  
  # 5. 全データが消費されたかチェック
  if offset != data.len:
    raise newException(CandidDecodeError, "Unexpected data at end of message")
  
  return CandidDecodeResult(
    typeTable: typeTable,
    values: values
  )

# ================================================================================
# Candid Message Encoder
# ================================================================================

# 型テーブル構築用の型情報
type
  TypeDescriptor* = ref object
    case kind*: CandidType
    of ctRecord:
      recordFields*: seq[tuple[hash: uint32, fieldType: TypeDescriptor]]  # ハッシュ値を直接保持
    of ctVariant:
      variantFields*: seq[tuple[hash: uint32, fieldType: TypeDescriptor]]  # ハッシュ値を直接保持
    of ctOpt:
      optInnerType*: TypeDescriptor
    of ctVec:
      vecElementType*: TypeDescriptor
    of ctFunc:
      funcArgs*: seq[TypeDescriptor]
      funcReturns*: seq[TypeDescriptor]
      funcAnnotations*: seq[byte]
    of ctService:
      serviceMethods*: seq[tuple[hash: uint32, methodType: TypeDescriptor]]  # ハッシュ値を直接保持
    else:
      discard


# 型テーブル構築時の作業用データ
type TypeBuilder* = object
  typeTable*: seq[TypeTableEntry]
  typeIndexMap*: Table[string, int]  # 型のハッシュ→インデックスのマップ


proc getTypeSignature(typeDesc: TypeDescriptor): string =
  ## 型の一意な文字列表現を生成（重複除去用）
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
    result = $typeDesc.kind


proc inferTypeDescriptor(value: CandidValue): TypeDescriptor =
  ## CandidValueから型記述子を推論
  result = TypeDescriptor(kind: value.kind)
  case value.kind:
  of ctRecord:
    result.recordFields = @[]
    for hash, fieldValue in value.recordVal.values:
      # ハッシュ値を直接使用（二重計算を避ける）
      result.recordFields.add((hash: hash, fieldType: inferTypeDescriptor(fieldValue)))
  of ctVariant:
    # バリアントの場合、選択されたタグのみから型を推論
    result.variantFields = @[(hash: value.variantVal.tag, fieldType: inferTypeDescriptor(value.variantVal.value))]
  of ctOpt:
    if value.optVal.isSome:
      result.optInnerType = inferTypeDescriptor(value.optVal.get())
    else:
      # null値の場合、内部型を推論できないため、とりあえずnullとする
      result.optInnerType = TypeDescriptor(kind: ctNull)
  of ctVec:
    if value.vecVal.len > 0:
      result.vecElementType = inferTypeDescriptor(value.vecVal[0])
    else:
      # 空ベクタの場合、要素型を推論できないため、emptyとする
      result.vecElementType = TypeDescriptor(kind: ctEmpty)
  else:
    discard


proc isPrimitiveType(candidType: CandidType): bool =
  ## 基本型かどうかを判定
  case candidType:
  of ctNull, ctBool, ctNat, ctInt, ctNat8, ctNat16, ctNat32, ctNat64,
     ctInt8, ctInt16, ctInt32, ctInt64, ctFloat32, ctFloat64,
     ctText, ctReserved, ctEmpty, ctPrincipal:
    return true
  else:
    return false


proc typeCodeFromCandidType(candidType: CandidType): int =
  ## CandidTypeから型コードを取得
  case candidType:
  of ctNull: -1
  of ctBool: -2
  of ctNat: -3
  of ctInt: -4
  of ctNat8: -5
  of ctNat16: -6
  of ctNat32: -7
  of ctNat64: -8
  of ctInt8: -9
  of ctInt16: -10
  of ctInt32: -11
  of ctInt64: -12
  of ctFloat32: -13
  of ctFloat64: -14
  of ctText: -15
  of ctReserved: -16
  of ctEmpty: -17
  of ctOpt: -18
  of ctVec: -19
  of ctRecord: -20
  of ctVariant: -21
  of ctFunc: -22
  of ctService: -23
  of ctPrincipal: -24
  else:
    raise newException(ValueError, "Unsupported type for encoding: " & $candidType)


proc addTypeToTable(builder: var TypeBuilder, typeDesc: TypeDescriptor): int =
  ## 型テーブルに型を追加し、インデックスを返す（重複チェック付き）
  let signature = getTypeSignature(typeDesc)
  if signature in builder.typeIndexMap:
    return builder.typeIndexMap[signature]
  
  # 新しい型エントリを作成
  let newIndex = builder.typeTable.len
  builder.typeIndexMap[signature] = newIndex
  
  var entry = TypeTableEntry(kind: typeDesc.kind)
  
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
  
  builder.typeTable.add(entry)
  return newIndex


proc encodeTypeTableEntry(entry: TypeTableEntry): seq[byte] =
  ## 型テーブルエントリをエンコード
  result = @[]
  
  # 型コードをSLEB128でエンコード
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
  ## 基本型の値をエンコード
  result = @[]
  
  case value.kind:
  of ctNull:
    discard  # nullは値を持たない
  
  of ctBool:
    result.add(if value.boolVal: byte(1) else: byte(0))
  
  of ctNat:
    result.add(encodeULEB128(uint(value.natVal)))
  
  of ctInt:
    result.add(encodeSLEB128(int32(value.intVal)))
  
  of ctNat8:
    result.add(byte(value.natVal))
  
  of ctNat16:
    var val = uint16(value.natVal)
    result.setLen(2)
    littleEndian16(addr result[0], addr val)
  
  of ctNat32:
    var val = uint32(value.natVal)
    result.setLen(4)
    littleEndian32(addr result[0], addr val)
  
  of ctNat64:
    var val = uint64(value.natVal)
    result.setLen(8)
    littleEndian64(addr result[0], addr val)
  
  of ctInt8:
    result.add(byte(value.intVal))
  
  of ctInt16:
    var val = int16(value.intVal)
    result.setLen(2)
    littleEndian16(addr result[0], addr val)
  
  of ctInt32:
    var val = int32(value.intVal)
    result.setLen(4)
    littleEndian32(addr result[0], addr val)
  
  of ctInt64:
    var val = int64(value.intVal)
    result.setLen(8)
    littleEndian64(addr result[0], addr val)
  
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
    result.add(1.byte) # IDフォーム識別子
    result.add(encodeULEB128(uint(principalBytes.len)))
    result.add(principalBytes)
  
  of ctReserved:
    discard  # reservedは値を持たない
  
  of ctEmpty:
    discard  # emptyは値を持たない
  
  else:
    raise newException(ValueError, "Not a primitive type: " & $value.kind)

proc encodeValue(value: CandidValue, typeRef: int, typeTable: seq[TypeTableEntry]): seq[byte] =
  ## 値をエンコード（基本型・複合型両対応）
  result = @[]
  
  if typeRef < 0:
    # 基本型
    result.add(encodePrimitiveValue(value))
  else:
    # 複合型
    let typeEntry = typeTable[typeRef]
    case typeEntry.kind:
    of ctRecord:
      # レコードの各フィールドを型テーブルの順序でエンコード
      for fieldInfo in typeEntry.recordFields:
        if fieldInfo.hash in value.recordVal.values:
          let fieldValue = value.recordVal.values[fieldInfo.hash]
          result.add(encodeValue(fieldValue, fieldInfo.fieldType, typeTable))
        else:
          raise newException(ValueError, "Missing field in record: " & $fieldInfo.hash)
    
    of ctVariant:
      # 選択されたタグのインデックスを探す
      var tagIndex = -1
      for i, fieldInfo in typeEntry.variantFields:
        if fieldInfo.hash == value.variantVal.tag:
          tagIndex = i
          break
      
      if tagIndex == -1:
        raise newException(ValueError, "Invalid variant tag: " & $value.variantVal.tag)
      
      result.add(encodeULEB128(uint(tagIndex)))
      result.add(encodeValue(value.variantVal.value, typeEntry.variantFields[tagIndex].fieldType, typeTable))
    
    of ctOpt:
      if value.optVal.isSome:
        result.add(encodeULEB128(1))  # has value
        result.add(encodeValue(value.optVal.get(), typeEntry.optInnerType, typeTable))
      else:
        result.add(encodeULEB128(0))  # no value
    
    of ctVec:
      result.add(encodeULEB128(uint(value.vecVal.len)))
      for element in value.vecVal:
        result.add(encodeValue(element, typeEntry.vecElementType, typeTable))
    
    of ctFunc:
      # 関数参照: principal + method name
      let principalBytes = value.funcVal.principal.bytes
      result.add(encodeULEB128(uint(principalBytes.len)))
      result.add(principalBytes)
      
      let methodNameBytes = cast[seq[byte]](value.funcVal.methodName)
      result.add(encodeULEB128(uint(methodNameBytes.len)))
      result.add(methodNameBytes)
    
    of ctService:
      # サービス参照: principal のみ
      let principalBytes = value.serviceVal.bytes
      result.add(encodeULEB128(uint(principalBytes.len)))
      result.add(principalBytes)
    
    else:
      raise newException(ValueError, "Unsupported composite type for encoding: " & $typeEntry.kind)

proc encodeCandidMessage*(values: seq[CandidValue]): seq[byte] =
  ## Candidメッセージをエンコードする
  result = @[]
  
  # 1. 魔法数を追加
  result.add(magicHeader)
  
  # 2. 型テーブルを構築
  var builder = TypeBuilder(
    typeTable: @[],
    typeIndexMap: initTable[string, int]()
  )
  
  var valueTypes: seq[int] = @[]
  
  # 各値の型を分析して型テーブルに追加
  for value in values:
    let typeDesc = inferTypeDescriptor(value)
    let typeRef = if isPrimitiveType(value.kind):
      typeCodeFromCandidType(value.kind)
    else:
      addTypeToTable(builder, typeDesc)
    valueTypes.add(typeRef)
  
  # 3. 型テーブルをエンコード
  result.add(encodeULEB128(uint(builder.typeTable.len)))
  for entry in builder.typeTable:
    result.add(encodeTypeTableEntry(entry))
  
  # 4. 型シーケンスをエンコード
  result.add(encodeULEB128(uint(valueTypes.len)))
  for typeRef in valueTypes:
    result.add(encodeSLEB128(int32(typeRef)))
  
  # 5. 値シーケンスをエンコード
  for i, value in values:
    result.add(encodeValue(value, valueTypes[i], builder.typeTable))

# ================================================================================
# Convenience constructors for CandidValue
# ================================================================================

proc newCandidNull*(): CandidValue =
  CandidValue(kind: ctNull)

proc newCandidBool*(value: bool): CandidValue =
  CandidValue(kind: ctBool, boolVal: value)

proc newCandidNat*(value: Natural): CandidValue =
  CandidValue(kind: ctNat, natVal: value)

proc newCandidInt*(value: int): CandidValue =
  CandidValue(kind: ctInt, intVal: value)

proc newCandidFloat*(value: float32): CandidValue =
  CandidValue(kind: ctFloat32, float32Val: value)

proc newCandidFloat*(value: float): CandidValue =
  newCandidFloat(value.float32)

proc newCandidText*(value: string): CandidValue =
  CandidValue(kind: ctText, textVal: value)

proc newCandidPrincipal*(value: Principal): CandidValue =
  CandidValue(kind: ctPrincipal, principalVal: value)

proc newCandidRecord*(values: Table[string, CandidValue]): CandidValue =
  var record = CandidRecord(values: initTable[uint32, CandidValue]())
  for key, value in values:
    record[key] = value
  CandidValue(kind: ctRecord, recordVal: record)

proc newCandidVariant*(tag: string, value: CandidValue): CandidValue =
  let variant = CandidVariant(tag: candidHash(tag), value: value)
  CandidValue(kind: ctVariant, variantVal: variant)

proc newCandidOpt*(value: Option[CandidValue]): CandidValue =
  CandidValue(kind: ctOpt, optVal: value)

proc newCandidVec*(values: seq[CandidValue]): CandidValue =
  CandidValue(kind: ctVec, vecVal: values)

proc newCandidFunc*(principal: Principal, methodName: string): CandidValue =
  CandidValue(kind: ctFunc, funcVal: (principal: principal, methodName: methodName))

proc newCandidService*(principal: Principal): CandidValue =
  CandidValue(kind: ctService, serviceVal: principal)

# ================================================================================
# String conversion for CandidValue
# ================================================================================

proc `$`*(value: CandidValue): string =
  ## CandidValue を文字列に変換する
  case value.kind:
  of ctNull:
    result = "null"
  of ctBool:
    result = $value.boolVal
  of ctNat, ctNat8, ctNat16, ctNat32, ctNat64:
    result = $value.natVal
  of ctInt, ctInt8, ctInt16, ctInt32, ctInt64:
    result = $value.intVal
  of ctFloat32:
    result = $value.float32Val
  of ctFloat64:
    result = $value.float64Val
  of ctText:
    result = "\"" & value.textVal & "\""
  of ctPrincipal:
    result = "principal \"" & $value.principalVal & "\""
  of ctRecord:
    result = "record {"
    var first = true
    for hash, fieldValue in value.recordVal.values:
      if not first:
        result.add("; ")
      result.add($hash & " = " & $fieldValue)
      first = false
    result.add("}")
  of ctVariant:
    result = "variant {" & $value.variantVal.tag & " = " & $value.variantVal.value & "}"
  of ctOpt:
    if value.optVal.isSome:
      result = "opt " & $value.optVal.get()
    else:
      result = "null"
  of ctVec:
    result = "vec ["
    for i, elem in value.vecVal:
      if i > 0:
        result.add(", ")
      result.add($elem)
    result.add("]")
  of ctFunc:
    result = "func \"" & $value.funcVal.principal & "\"." & value.funcVal.methodName
  of ctService:
    result = "service \"" & $value.serviceVal & "\""
  of ctReserved:
    result = "reserved"
  of ctEmpty:
    result = "empty"
  of ctQuery:
    result = "query"
  of ctOneway:
    result = "oneway"  
  of ctCompositeQuery:
    result = "composite_query"


proc `$`*(record: CandidRecord): string =
  ## CandidRecord を文字列に変換する
  result = "{"
  var first = true
  for hash, value in record.values:
    if not first:
      result.add("; ")
    result.add($hash & " = " & $value)
    first = false
  result.add("}")


proc `$`*(variant: CandidVariant): string =
  ## CandidVariant を文字列に変換する
  result = "{" & $variant.tag & " = " & $variant.value & "}"


proc `$`*(entry: TypeTableEntry): string =
  ## TypeTableEntry を文字列に変換する
  result = $entry.kind


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

