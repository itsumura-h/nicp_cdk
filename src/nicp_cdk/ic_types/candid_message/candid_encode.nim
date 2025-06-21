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
    # 基本型や未処理の型のフォールバック
    result = $typeDesc.kind



proc inferTypeDescriptor(value: CandidValue): TypeDescriptor =
  ## CandidValueから型記述子を推論
  result = TypeDescriptor(kind: value.kind)
  case value.kind:
  of ctRecord:
    result.recordFields = @[]
    for fieldName, fieldValue in value.recordVal.fields:
      # フィールド名からハッシュ値を計算
      let fieldHash = candidHash(fieldName)
      result.recordFields.add((hash: fieldHash, fieldType: inferTypeDescriptor(fieldValue)))
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
      let firstElement = value.vecVal[0]
      if firstElement.kind == ctBlob:
        # vec blob の場合、要素はblob型（これはvec nat8として扱われる）
        result.vecElementType = TypeDescriptor(kind: ctVec, vecElementType: TypeDescriptor(kind: ctNat8))
      else:
        result.vecElementType = inferTypeDescriptor(firstElement)
    else:
      # 空ベクタの場合、要素型を推論できないため、emptyとする
      result.vecElementType = TypeDescriptor(kind: ctEmpty)
  of ctBlob:
    # Blobは常にvec nat8として処理される
    discard
  else:
    discard


proc addTypeToTable(builder: var TypeBuilder, typeDesc: TypeDescriptor): int =
  ## 型テーブルに型を追加し、インデックスを返す（重複チェック付き）
  let signature = getTypeSignature(typeDesc)
  if signature in builder.typeIndexMap:
    return builder.typeIndexMap[signature]
  
  # 新しい型エントリを作成
  let newIndex = builder.typeTable.len
  builder.typeIndexMap[signature] = newIndex
  
  # まず空のエントリを追加してインデックスを確保
  var entry = TypeTableEntry(kind: typeDesc.kind)
  builder.typeTable.add(entry)
  
  # その後詳細を設定
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
    # Blobはvec nat8として処理される
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
  
  # エントリの詳細を更新
  builder.typeTable[newIndex] = entry
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
  
  of ctBlob:
    # Blobはvec nat8として処理されるため、nat8の型コードを出力
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
    # floatはfloat32として扱う
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
    result.add(1.byte) # IDフォーム識別子
    result.add(encodeULEB128(uint(principalBytes.len)))
    result.add(principalBytes)
  
  of ctBlob:
    # Blobはvec nat8として処理される
    result.add(encodeULEB128(uint(value.blobVal.len)))
    for byteVal in value.blobVal:
      result.add(byteVal)
  
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
        var foundField: bool = false
        var fieldValue: CandidValue
        
        # レコード内のフィールドを検索（フィールド名のハッシュ値で比較）
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
      # valueの種類を確認してからvariantVal にアクセス
      if value.kind == ctVariant:
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
        # ctBlobの場合は特別処理（vec nat8として処理）
        result.add(encodeULEB128(uint(value.blobVal.len)))
        for byteVal in value.blobVal:
          result.add(byteVal)
      else:
        # 通常のvec処理
        result.add(encodeULEB128(uint(value.vecVal.len)))
        for element in value.vecVal:
          result.add(encodeValue(element, typeEntry.vecElementType, typeTable))
    
    of ctBlob:
      # ctBlobケースを復活 - vec blob対応のため必要
      result.add(encodeULEB128(uint(value.blobVal.len)))
      for byteVal in value.blobVal:
        result.add(byteVal)
    
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


# ================================================================================
# Public Procedures
# ================================================================================
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
    let typeRef = if value.kind == ctBlob:
      # Blobはvec nat8として型テーブルに追加（基本型でなく複合型として扱う）
      let vecTypeDesc = TypeDescriptor(kind: ctVec, vecElementType: TypeDescriptor(kind: ctNat8))
      addTypeToTable(builder, vecTypeDesc)
    elif value.kind == ctVec and value.vecVal.len > 0 and value.vecVal[0].kind == ctBlob:
      # vec blob (seq[seq[uint8]]) の場合の特別処理
      let blobTypeDesc = TypeDescriptor(kind: ctVec, vecElementType: TypeDescriptor(kind: ctNat8))
      let vecBlobTypeDesc = TypeDescriptor(kind: ctVec, vecElementType: blobTypeDesc)
      addTypeToTable(builder, vecBlobTypeDesc)
    elif isPrimitiveType(value.kind):
      typeCodeFromCandidType(value.kind)
    else:
      let typeDesc = inferTypeDescriptor(value)
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
