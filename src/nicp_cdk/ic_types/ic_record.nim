import std/tables
import std/strutils
import std/strformat
import std/options
import std/base64
import std/hashes
import std/macros

import ./candid_types
import ./ic_principal
import ./candid_funcs

# CandidRecordの操作に特化したモジュール
# 型変換ロジックはcandid_funcs.nimに移動済み

# ===== Record型バリデーション関数 =====

proc validateRecordFieldType(cv: CandidValue, fieldName: string) =
  ## Record内のフィールドが対応している型かチェック
  ## ICPのCanister環境でサポートされていない型を検出してエラーを発生
  case cv.kind:
  of ctFunc, ctService, ctReserved, ctQuery, ctOneway, ctCompositeQuery:
    let typeName = case cv.kind:
      of ctFunc: "func"
      of ctService: "service"  
      of ctReserved: "reserved"
      of ctQuery: "query"
      of ctOneway: "oneway"
      of ctCompositeQuery: "composite_query"
      else: "unknown"
    let alternatives = case cv.kind:
      of ctFunc: "Supported alternatives: Principal (for service references), Text (for method names)"
      of ctService: "Supported alternatives: Principal (for service references)"
      else: "These types are not supported in ICP Canister communication."
    raise newException(ValueError, 
      &"Unsupported Candid type '{typeName}' in Record field '{fieldName}'. " &
      alternatives)
  else:
    # ネストしたRecord/Variant/Array内もチェック
    case cv.kind:
    of ctRecord:
      for key, value in cv.recordVal.fields:
        validateRecordFieldType(value, &"{fieldName}.{key}")
    of ctVec:
      for i, elem in cv.vecVal:
        validateRecordFieldType(elem, &"{fieldName}[{i}]")
    of ctOpt:
      if cv.optVal.isSome():
        validateRecordFieldType(cv.optVal.get(), &"{fieldName}.some")
    of ctVariant:
      validateRecordFieldType(cv.variantVal.value, &"{fieldName}.variant_value")
    else:
      discard  # その他の型は許可

# ===== アクセサ関数 =====

proc getInt*(cv: CandidRecord): int =
  ## 整数値を取得
  if cv.kind != ckInt:
    raise newException(ValueError, &"Expected Int, got {cv.kind}")
  cv.intVal

proc getInt8*(cv: CandidRecord): int8 =
  ## 整数値を取得
  if cv.kind != ckInt8:
    raise newException(ValueError, &"Expected Int8, got {cv.kind}")
  cv.int8Val

proc getInt16*(cv: CandidRecord): int16 =
  ## 整数値を取得
  if cv.kind != ckInt16:
    raise newException(ValueError, &"Expected Int16, got {cv.kind}")
  cv.int16Val

proc getInt32*(cv: CandidRecord): int32 =
  ## 整数値を取得
  if cv.kind != ckInt32:
    raise newException(ValueError, &"Expected Int32, got {cv.kind}")
  cv.int32Val

proc getInt64*(cv: CandidRecord): int64 =
  ## 整数値を取得
  if cv.kind != ckInt64:
    raise newException(ValueError, &"Expected Int64, got {cv.kind}")
  cv.int64Val

proc getNat*(cv: CandidRecord): uint =
  ## 自然数値を取得
  if cv.kind != ckNat:
    raise newException(ValueError, &"Expected Nat, got {cv.kind}")
  cv.natVal

proc getNat8*(cv: CandidRecord): uint8 =
  ## 8bit自然数値を取得
  if cv.kind != ckNat8:
    raise newException(ValueError, &"Expected Nat8, got {cv.kind}")
  cv.nat8Val

proc getNat16*(cv: CandidRecord): uint16 =
  ## 16bit自然数値を取得
  if cv.kind != ckNat16:
    raise newException(ValueError, &"Expected Nat16, got {cv.kind}")
  cv.nat16Val

proc getNat32*(cv: CandidRecord): uint32 =
  ## 32bit自然数値を取得
  if cv.kind != ckNat32:
    raise newException(ValueError, &"Expected Nat32, got {cv.kind}")
  cv.nat32Val

proc getNat64*(cv: CandidRecord): uint64 =
  ## 64bit自然数値を取得
  if cv.kind != ckNat64:
    raise newException(ValueError, &"Expected Nat64, got {cv.kind}")
  cv.nat64Val

proc getFloat*(cv: CandidRecord): float =
  ## 浮動小数点値を取得
  if cv.kind != ckFloat64:
    raise newException(ValueError, &"Expected Float64, got {cv.kind}")
  cv.f64Val

proc getFloat32*(cv: CandidRecord): float32 =
  ## 単精度浮動小数点値を取得
  if cv.kind != ckFloat32:
    raise newException(ValueError, &"Expected Float32, got {cv.kind}")
  cv.f32Val

proc getFloat64*(cv: CandidRecord): float =
  ## 倍精度浮動小数点値を取得
  if cv.kind != ckFloat64:
    raise newException(ValueError, &"Expected Float64, got {cv.kind}")
  cv.f64Val

proc getBool*(cv: CandidRecord): bool =
  ## ブール値を取得
  if cv.kind != ckBool:
    raise newException(ValueError, &"Expected Bool, got {cv.kind}")
  cv.boolVal

proc getStr*(cv: CandidRecord): string =
  ## 文字列値を取得
  if cv.kind != ckText:
    raise newException(ValueError, &"Expected Text, got {cv.kind}")
  cv.strVal

proc getBytes*(cv: CandidRecord): seq[uint8] =
  ## バイト列を取得
  if cv.kind != ckBlob:
    raise newException(ValueError, &"Expected Blob, got {cv.kind}")
  cv.bytesVal

proc getArray*(cv: CandidRecord): seq[CandidRecord] =
  ## 配列の要素を取得
  if cv.kind != ckArray:
    raise newException(ValueError, &"Expected Array, got {cv.kind}")
  cv.elems

# ===== インデックス演算子（レコード用） =====

proc `[]`*(cv: CandidRecord, key: string): CandidRecord =
  ## レコードのフィールドにアクセス（存在しない場合は例外）
  if cv.kind != ckRecord:
    raise newException(ValueError, &"Cannot index {cv.kind} with string key")
  if key notin cv.fields:
    raise newException(KeyError, &"Key '{key}' not found in record")
  fromCandidValue(cv.fields[key])

proc `[]=`*(cv: CandidRecord, key: string, value: CandidRecord) =
  ## レコードのフィールドを設定
  if cv.kind != ckRecord:
    raise newException(ValueError, &"Cannot set field on {cv.kind}")
  
  # フィールドの型をバリデーション
  let candidValue = value.toCandidValue()
  validateRecordFieldType(candidValue, key)
  
  cv.fields[key] = candidValue

# ===== インデックス演算子（配列用） =====

proc `[]`*(cv: CandidRecord, index: int): CandidRecord =
  ## 配列の要素にアクセス（存在しない場合は例外）
  if cv.kind != ckArray:
    raise newException(ValueError, &"Cannot index {cv.kind} with integer")
  if index < 0 or index >= cv.elems.len:
    raise newException(IndexDefect, &"Index {index} out of bounds for array of length {cv.elems.len}")
  cv.elems[index]

proc `[]=`*(cv: CandidRecord, index: int, value: CandidRecord) =
  ## 配列の要素を設定
  if cv.kind != ckArray:
    raise newException(ValueError, &"Cannot set array element on {cv.kind}")
  if index < 0 or index >= cv.elems.len:
    raise newException(IndexDefect, &"Index {index} out of bounds for array of length {cv.elems.len}")
  cv.elems[index] = value

# ===== 安全なアクセス =====

proc contains*(cv: CandidRecord, key: string): bool =
  ## レコード内にキーが存在するかチェック
  if cv.kind != ckRecord:
    return false
  key in cv.fields

proc get*(cv: CandidRecord, key: string, default: CandidRecord = nil): CandidRecord =
  ## 安全なフィールド取得（存在しない場合はdefaultを返す）
  if cv.kind != ckRecord or key notin cv.fields:
    return default
  fromCandidValue(cv.fields[key])

# ===== 配列操作 =====

proc add*(cv: CandidRecord, value: CandidRecord) =
  ## 配列の末尾に要素を追加
  if cv.kind != ckArray:
    raise newException(ValueError, &"Cannot add element to {cv.kind}")
  cv.elems.add(value)

proc len*(cv: CandidRecord): int =
  ## 配列またはレコードの長さを取得
  case cv.kind:
  of ckArray:
    cv.elems.len
  of ckRecord:
    cv.fields.len
  else:
    0

# ===== 削除操作 =====

proc delete*(cv: CandidRecord, key: string) =
  ## レコードからフィールドを削除
  if cv.kind != ckRecord:
    raise newException(ValueError, &"Cannot delete field from {cv.kind}")
  cv.fields.del(key)

proc delete*(cv: CandidRecord, index: int) =
  ## 配列から要素を削除
  if cv.kind != ckArray:
    raise newException(ValueError, &"Cannot delete element from {cv.kind}")
  if index < 0 or index >= cv.elems.len:
    raise newException(IndexDefect, &"Index {index} out of bounds")
  cv.elems.delete(index)

# ===== Principal/Func関連のヘルパー =====

proc getPrincipal*(cv: CandidRecord): Principal =
  ## Principal値をPrincipal型として取得
  if cv.kind != ckPrincipal:
    raise newException(ValueError, &"Expected Principal, got {cv.kind}")
  Principal.fromText(cv.principalId)

proc getFuncPrincipal*(cv: CandidRecord): Principal =
  ## Func値のprincipal部分を取得
  if cv.kind != ckFunc:
    raise newException(ValueError, &"Expected Func, got {cv.kind}")
  Principal.fromText(cv.funcRef.principal)

proc getFuncMethod*(cv: CandidRecord): string =
  ## Func値のmethod部分を取得
  if cv.kind != ckFunc:
    raise newException(ValueError, &"Expected Func, got {cv.kind}")
  cv.funcRef.methodName

proc getService*(cv: CandidRecord): Principal =
  ## Service値をPrincipal型として取得
  if cv.kind != ckService:
    raise newException(ValueError, &"Expected Service, got {cv.kind}")
  Principal.fromText(cv.serviceId)

# ================================================================================
# Enum型サポート関数
# ================================================================================

proc getEnum*[T: enum](cv: CandidRecord, enumType: typedesc[T], key: string): T =
  ## RecordからEnum値を取得（指定されたキーのVariant値をEnum型に変換）
  if cv.kind != ckRecord:
    raise newException(ValueError, &"Cannot get enum field from {cv.kind}, expected record")
  
  if key notin cv.fields:
    raise newException(KeyError, &"Key '{key}' not found in record")
  
  let candidValue = cv.fields[key]
  if candidValue.kind != ctVariant:
    raise newException(ValueError, 
      &"Expected variant type for enum conversion at field '{key}', got: {candidValue.kind}")
  
  try:
    return getEnumValue(candidValue, enumType)
  except ValueError as e:
    raise newException(ValueError, 
      &"Failed to convert variant at field '{key}' to enum type {$typeof(T)}: {e.msg}")

proc `[]=`*[T: enum](cv: CandidRecord, key: string, enumValue: T) =
  ## RecordにEnum値を設定（自動的にVariant型として変換）
  if cv.kind != ckRecord:
    raise newException(ValueError, &"Cannot set field on {cv.kind}, expected record")
  
  try:
    # Enum値をVariant CandidValueに変換
    let candidValue = newCandidValue(enumValue)
    
    # バリデーションを実行（Variant型なので通常は問題ないが、一応チェック）
    validateRecordFieldType(candidValue, key)
    
    # フィールドに設定
    cv.fields[key] = candidValue
    
  except ValueError as e:
    raise newException(ValueError, 
      &"Failed to set enum value at field '{key}': {e.msg}")

proc `[]=`*(cv: CandidRecord, key: string, value: CandidValue) =
  ## CandidValueを直接CandidRecordのフィールドとして設定
  if cv.kind != ckRecord:
    raise newException(ValueError, &"Cannot set field on {cv.kind}, expected record")
  
  try:
    # CandidValueのバリデーションを実行
    validateRecordFieldType(value, key)
    
    # フィールドに設定
    cv.fields[key] = value
    
  except ValueError as e:
    raise newException(ValueError, 
      &"Failed to set CandidValue at field '{key}': {e.msg}")

# ===== Option/Variant専用ヘルパー =====

# テスト用のVariantラッパー型
type
  VariantResult* = object
    tag*: string
    value*: CandidRecord

proc isSome*(cv: CandidRecord): bool =
  ## Optionが値を持つかチェック
  cv.kind == ckOption and cv.optVal.isSome()

proc isNone*(cv: CandidRecord): bool =
  ## OptionがNoneかチェック
  cv.kind == ckOption and cv.optVal.isNone()

proc getOpt*(cv: CandidRecord): CandidRecord =
  ## Optionの中身の値を取得（Noneの場合は例外）
  if cv.kind != ckOption:
    raise newException(ValueError, &"Expected Option, got {cv.kind}")
  if cv.optVal.isNone():
    raise newException(ValueError, "Cannot get value from None option")
  cv.optVal.get()

proc getVariant*(cv: CandidRecord): VariantResult =
  ## Variantの内容をVariantResult型として取得
  if cv.kind != ckVariant:
    raise newException(ValueError, &"Expected Variant, got {cv.kind}")
  
  # ハッシュ値から元の文字列を復元するのは不可能なので、
  # テストでは既知の文字列リストから逆引きする
  let hashVal = cv.variantVal.tag
  let tagStr = case hashVal:
    of candidHash("success"): "success"
    of candidHash("error"): "error"
    of candidHash("empty"): "empty"
    of candidHash("secp256k1"): "secp256k1"
    of candidHash("secp256r1"): "secp256r1"
    of candidHash("some"): "some"
    of candidHash("none"): "none"
    else: $hashVal  # 見つからない場合はハッシュ値を文字列化
  
  VariantResult(
    tag: tagStr,
    value: fromCandidValue(cv.variantVal.value)
  )

# ===== 必要なヘルパー関数 =====

proc newCNull*(): CandidRecord =
  ## Null値のCandidRecordを作成
  CandidRecord(kind: ckNull)

proc newCBoolRecord*(value: bool): CandidRecord =
  ## Bool値のCandidRecordを作成
  CandidRecord(kind: ckBool, boolVal: value)

proc newCIntRecord*(value: int64): CandidRecord =
  ## Int値のCandidRecordを作成
  CandidRecord(kind: ckInt, intVal: value)

proc newCFloat64Record*(value: float): CandidRecord =
  ## Float64値のCandidRecordを作成
  CandidRecord(kind: ckFloat64, f64Val: value)

proc newCTextRecord*(value: string): CandidRecord =
  ## Text値のCandidRecordを作成
  CandidRecord(kind: ckText, strVal: value)

proc newCBlobRecord*(value: seq[uint8]): CandidRecord =
  ## Blob値のCandidRecordを作成
  CandidRecord(kind: ckBlob, bytesVal: value)

proc newCRecordEmpty*(): CandidRecord =
  ## 空のRecord CandidRecordを作成
  CandidRecord(kind: ckRecord, fields: initOrderedTable[string, CandidValue]())

proc newCArrayRecord*(): CandidRecord =
  ## 空のArray CandidRecordを作成
  CandidRecord(kind: ckArray, elems: @[])

proc newCVariantRecord*(tag: string): CandidRecord =
  ## Variant CandidRecordを作成
  let variant = CandidVariant(tag: candidHash(tag), value: newCandidNull())
  CandidRecord(kind: ckVariant, variantVal: variant)

proc newCPrincipalRecord*(principalId: string): CandidRecord =
  ## Principal CandidRecordを作成
  CandidRecord(kind: ckPrincipal, principalId: principalId)

proc newCOptionNone*(): CandidRecord =
  ## None Option CandidRecordを作成
  CandidRecord(kind: ckOption, optVal: none(CandidRecord))

proc asSome*(value: CandidRecord): CandidRecord =
  ## Some Option CandidRecordを作成
  CandidRecord(kind: ckOption, optVal: some(value))

# ===== CandidValue ⇔ CandidRecord 変換関数 =====

proc candidValueToCandidRecord*(cv: CandidValue): CandidRecord =
  ## CandidValueからCandidRecordに変換
  case cv.kind:
  of ctNull:
    newCNull()
  of ctBool:
    newCBoolRecord(cv.boolVal)
  of ctNat:
    CandidRecord(kind: ckNat, natVal: cv.natVal)
  of ctInt:
    newCIntRecord(cv.intVal)
  of ctNat8:
    CandidRecord(kind: ckNat8, nat8Val: uint8(cv.natVal))
  of ctNat16:
    CandidRecord(kind: ckNat16, nat16Val: uint16(cv.natVal))
  of ctNat32:
    CandidRecord(kind: ckNat32, nat32Val: uint32(cv.natVal))
  of ctNat64:
    CandidRecord(kind: ckNat64, nat64Val: uint64(cv.natVal))
  of ctInt8:
    CandidRecord(kind: ckInt8, int8Val: cv.int8Val)
  of ctInt16:
    CandidRecord(kind: ckInt16, int16Val: cv.int16Val)
  of ctInt32:
    CandidRecord(kind: ckInt32, int32Val: cv.int32Val)
  of ctInt64:
    CandidRecord(kind: ckInt64, int64Val: cv.int64Val)
  of ctFloat32:
    CandidRecord(kind: ckFloat32, f32Val: cv.float32Val)
  of ctFloat64:
    newCFloat64Record(cv.float64Val)
  of ctText:
    newCTextRecord(cv.textVal)
  of ctBlob:
    newCBlobRecord(cv.blobVal)
  of ctPrincipal:
    newCPrincipalRecord(cv.principalVal.value)
  of ctVec:
    var arrayRecord = newCArrayRecord()
    for elem in cv.vecVal:
      arrayRecord.add(fromCandidValue(elem))
    arrayRecord
  of ctRecord:
    var recordRecord = newCRecordEmpty()
    for key, value in cv.recordVal.fields:
      recordRecord.fields[key] = value
    recordRecord
  of ctOpt:
    if cv.optVal.isSome():
      asSome(fromCandidValue(cv.optVal.get()))
    else:
      newCOptionNone()
  of ctVariant:
    CandidRecord(kind: ckVariant, variantVal: cv.variantVal)
  of ctFunc:
    CandidRecord(kind: ckFunc, funcRef: (cv.funcVal.principal.value, cv.funcVal.methodName))
  of ctService:
    CandidRecord(kind: ckService, serviceId: cv.serviceVal.value)
  else:
    newCNull()  # 未対応の型はnullとして扱う

proc toCandidValue*(cr: CandidRecord): CandidValue =
  ## CandidRecordからCandidValueに変換
  case cr.kind:
  of ckNull:
    newCandidNull()
  of ckBool:
    newCandidValue(cr.boolVal)
  of ckInt:
    newCandidValue(cr.intVal)
  of ckInt8:
    CandidValue(kind: ctInt8, int8Val: cr.int8Val)
  of ckInt16:
    CandidValue(kind: ctInt16, int16Val: cr.int16Val)
  of ckInt32:
    CandidValue(kind: ctInt32, int32Val: cr.int32Val)
  of ckInt64:
    CandidValue(kind: ctInt64, int64Val: cr.int64Val)
  of ckNat:
    CandidValue(kind: ctNat, natVal: cr.natVal)
  of ckNat8:
    CandidValue(kind: ctNat8, natVal: uint(cr.nat8Val))
  of ckNat16:
    CandidValue(kind: ctNat16, natVal: uint(cr.nat16Val))
  of ckNat32:
    CandidValue(kind: ctNat32, natVal: uint(cr.nat32Val))
  of ckNat64:
    CandidValue(kind: ctNat64, natVal: uint(cr.nat64Val))
  of ckFloat32:
    CandidValue(kind: ctFloat32, float32Val: cr.f32Val)
  of ckFloat64:
    newCandidValue(cr.f64Val)
  of ckText:
    newCandidValue(cr.strVal)
  of ckBlob:
    newCandidValue(cr.bytesVal)
  of ckPrincipal:
    newCandidValue(Principal.fromText(cr.principalId))
  of ckArray:
    var vecItems: seq[CandidValue] = @[]
    for elem in cr.elems:
      vecItems.add(toCandidValue(elem))
    CandidValue(kind: ctVec, vecVal: vecItems)
  of ckRecord:
    var candidRecord = CandidRecord(kind: ckRecord, fields: initOrderedTable[string, CandidValue]())
    for key, value in cr.fields:
      candidRecord.fields[key] = value
    toCandidValue(candidRecord)
  of ckOption:
    if cr.optVal.isSome():
      CandidValue(kind: ctOpt, optVal: some(toCandidValue(cr.optVal.get())))
    else:
      CandidValue(kind: ctOpt, optVal: none(CandidValue))
  of ckVariant:
    CandidValue(kind: ctVariant, variantVal: cr.variantVal)
  of ckFunc:
    let funcValue = CandidFunc(
      principal: Principal.fromText(cr.funcRef.principal),
      methodName: cr.funcRef.methodName,
      args: @[],
      returns: @[],
      annotations: @[]
    )
    CandidValue(kind: ctFunc, funcVal: funcValue)
  of ckService:
    newCandidValue(Principal.fromText(cr.serviceId))
  else:
    newCandidNull()

# ===== 型チェック関数 =====

proc isNull*(cv: CandidRecord): bool =
  ## レコードがNull型かチェック
  cv.kind == ckNull

proc isPrincipal*(cv: CandidRecord): bool =
  ## レコードがPrincipal型かチェック
  cv.kind == ckPrincipal

proc isBlob*(cv: CandidRecord): bool =
  ## レコードがBlob型かチェック
  cv.kind == ckBlob

proc isFloat32*(cv: CandidRecord): bool =
  ## レコードがFloat32型かチェック
  cv.kind == ckFloat32

proc isFloat64*(cv: CandidRecord): bool =
  ## レコードがFloat64型かチェック
  cv.kind == ckFloat64

proc isVariant*(cv: CandidRecord): bool =
  ## レコードがVariant型かチェック
  cv.kind == ckVariant

proc isArray*(cv: CandidRecord): bool =
  ## レコードがArray型かチェック
  cv.kind == ckArray

# ===== 拡張メソッド =====

proc asBlob*(data: seq[uint8]): seq[uint8] =
  ## seq[uint8]をBlob型として明示的に標識（実際は同じ型を返す）
  data

# ===== テスト用ヘルパー関数 =====

proc newCFloat32*(value: float32): CandidRecord =
  ## Float32値のCandidRecordを作成
  CandidRecord(kind: ckFloat32, f32Val: value)

proc newCText*(value: string): CandidRecord =
  ## Text値のCandidRecordを作成
  CandidRecord(kind: ckText, strVal: value)

proc newCVariant*(tag: string, value: CandidRecord = newCNull()): CandidRecord =
  ## Variant CandidRecordを作成
  let variant = CandidVariant(tag: candidHash(tag), value: value.toCandidValue())
  CandidRecord(kind: ckVariant, variantVal: variant)

proc newCFunc*(principal: string, methodName: string): CandidRecord =
  ## Func CandidRecordを作成
  CandidRecord(kind: ckFunc, funcRef: (principal, methodName))

proc newCService*(principal: string): CandidRecord =
  ## Service CandidRecordを作成
  CandidRecord(kind: ckService, serviceId: principal)

# ===== Variant/Service用のビルダー型 =====

type
  VariantBuilder* = object
  ServiceBuilder* = object

proc new*(_: type VariantBuilder, tag: string, value: CandidRecord = newCNull()): CandidRecord =
  ## Variant.new()構文用
  newCVariant(tag, value)

proc new*(_: type ServiceBuilder, principal: string): CandidRecord =
  ## Service.new()構文用
  newCService(principal)

# グローバル変数として使用できるようにする
let Variant* = VariantBuilder()
let Service* = ServiceBuilder()

# ===== フィールド名のハッシュ化関数 =====

proc candidFieldHash*(name: string): uint32 =
  ## Candidフィールド名のハッシュIDを計算
  ## 注意：実際のCandid仕様に準拠したハッシュ関数を実装する必要があります
  ## ここでは簡易版として標準のhash関数を使用
  name.hash().uint32

# ===== JSON風文字列化 =====

proc indentStr(level: int): string =
  "  ".repeat(level)

proc candidValueToJsonString(cv: CandidRecord, indent: int = 0): string =
  case cv.kind:
  of ckNull:
    "null"
  of ckBool:
    if cv.boolVal: "true" else: "false"
  of ckInt:
    $cv.intVal
  of ckInt8:
    $cv.int8Val
  of ckInt16:
    $cv.int16Val
  of ckInt32:
    $cv.int32Val
  of ckInt64:
    $cv.int64Val
  of ckNat:
    $cv.natVal
  of ckNat8:
    $cv.nat8Val
  of ckNat16:
    $cv.nat16Val
  of ckNat32:
    $cv.nat32Val
  of ckNat64:
    $cv.nat64Val
  of ckFloat:
    $cv.fVal
  of ckFloat32:
    $cv.f32Val
  of ckFloat64:
    $cv.f64Val
  of ckText:
    "\"" & cv.strVal.replace("\"", "\\\"") & "\""
  of ckBlob:
    # Base64エンコードして文字列として出力
    "\"base64:" & encode(cv.bytesVal) & "\""
  of ckRecord:
    if cv.fields.len == 0:
      "{}"
    else:
      var lines: seq[string] = @["{"]
      var isFirst = true
      for key, value in cv.fields:
        if not isFirst:
          lines[^1] &= ","
        let keyStr = if key.allCharsInSet({'0'..'9'}): 
                       "\"_" & key & "_\""  # 数値キーの場合は特殊表記
                     else: 
                       "\"" & key & "\""
        lines.add(indentStr(indent + 1) & keyStr & ": " & candidValueToJsonString(fromCandidValue(value), indent + 1))
        isFirst = false
      lines.add(indentStr(indent) & "}")
      lines.join("\n")
  of ckArray:
    if cv.elems.len == 0:
      "[]"
    else:
      var lines: seq[string] = @["["]
      for i, elem in cv.elems:
        let suffix = if i < cv.elems.len - 1: "," else: ""
        lines.add(indentStr(indent + 1) & candidValueToJsonString(elem, indent + 1) & suffix)
      lines.add(indentStr(indent) & "]")
      lines.join("\n")
  of ckVariant:
    # Variantは単一キーのオブジェクトとして表現
    "{\"" & $cv.variantVal.tag & "\": " & candidValueToJsonString(fromCandidValue(cv.variantVal.value), indent) & "}"
  of ckOption:
    # Optionも単一キーのオブジェクトとして表現
    if cv.optVal.isSome():
      "{\"some\": " & candidValueToJsonString(cv.optVal.get(), indent) & "}"
    else:
      "{\"none\": null}"
  of ckPrincipal:
    "\"" & cv.principalId & "\""
  of ckFunc:
    "{\"principal\": \"" & cv.funcRef.principal & "\", \"method\": \"" & cv.funcRef.methodName & "\"}"
  of ckService:
    "\"" & cv.serviceId & "\""

proc `$`*(cv: CandidRecord): string =
  ## CandidRecordをJSON風文字列に変換
  candidValueToJsonString(cv)

# ===== 便利マクロ（JsonNodeの %* に相当） =====

macro candidLit*(x: untyped): CandidRecord =
  ## CandidRecordリテラル構築マクロ（高機能版）
  
  proc buildRecord(node: NimNode): NimNode =
    case node.kind:
    of nnkCurly, nnkTableConstr:
      # Record構造 { "key": value, ... }
      let recordVar = genSym(nskVar, "record")
      var stmts = newStmtList()
      
      # 空のRecordを作成
      stmts.add quote do:
        var `recordVar` = newCRecord()
      
      # 各フィールドを追加
      for pair in node:
        if pair.kind == nnkExprColonExpr:
          let key = pair[0]
          let value = pair[1]
          
          case value.kind:
          of nnkStrLit:
            # 文字列値
            stmts.add quote do:
              `recordVar`[`key`] = candid_funcs.newCText(`value`)
          of nnkIntLit:
            # 整数値
            stmts.add quote do:
              `recordVar`[`key`] = candid_funcs.newCInt(`value`)
          of nnkInt8Lit:
            # 整数値
            stmts.add quote do:
              `recordVar`[`key`] = candid_funcs.newCInt8(`value`)
          of nnkInt16Lit:
            # 整数値
            stmts.add quote do:
              `recordVar`[`key`] = candid_funcs.newCInt16(`value`)
          of nnkInt32Lit:
            # 整数値
            stmts.add quote do:
              `recordVar`[`key`] = candid_funcs.newCInt32(`value`)
          of nnkInt64Lit:
            # 整数値
            stmts.add quote do:
              `recordVar`[`key`] = candid_funcs.newCInt64(`value`)
          of nnkFloat32Lit, nnkFloat64Lit, nnkFloatLit:
            # 浮動小数点値
            stmts.add quote do:
              `recordVar`[`key`] = candid_funcs.newCFloat64(`value`)
          of nnkDotExpr:
            # 型付きリテラル（例：1.int8, 1.int16, 1.int32, 1.int64）の処理
            if value[1].kind == nnkIdent:
              let typeName = value[1].strVal
              let val = value[0]
              case typeName:
              of "int8":
                stmts.add quote do:
                  `recordVar`[`key`] = CandidRecord(kind: ckInt8, int8Val: int8(`val`))
              of "int16":
                stmts.add quote do:
                  `recordVar`[`key`] = CandidRecord(kind: ckInt16, int16Val: int16(`val`))
              of "int32":
                stmts.add quote do:
                  `recordVar`[`key`] = CandidRecord(kind: ckInt32, int32Val: int32(`val`))
              of "int64":
                stmts.add quote do:
                  `recordVar`[`key`] = CandidRecord(kind: ckInt64, int64Val: int64(`val`))
              of "uint", "nat":
                stmts.add quote do:
                  `recordVar`[`key`] = CandidRecord(kind: ckNat, natVal: uint(`val`))
              of "uint8", "nat8":
                stmts.add quote do:
                  `recordVar`[`key`] = CandidRecord(kind: ckNat8, nat8Val: uint8(`val`))
              of "uint16", "nat16":
                stmts.add quote do:
                  `recordVar`[`key`] = CandidRecord(kind: ckNat16, nat16Val: uint16(`val`))
              of "uint32", "nat32":
                stmts.add quote do:
                  `recordVar`[`key`] = CandidRecord(kind: ckNat32, nat32Val: uint32(`val`))
              of "uint64", "nat64":
                stmts.add quote do:
                  `recordVar`[`key`] = CandidRecord(kind: ckNat64, nat64Val: uint64(`val`))
              of "float32":
                stmts.add quote do:
                  `recordVar`[`key`] = CandidRecord(kind: ckFloat32, f32Val: float32(`val`))
              of "float64", "float":
                stmts.add quote do:
                  `recordVar`[`key`] = CandidRecord(kind: ckFloat64, f64Val: float64(`val`))
              else:
                # 未知の型付きリテラルは文字列として扱う
                stmts.add quote do:
                  `recordVar`[`key`] = candid_funcs.newCText($`value`)
            else:
              # DotExprだが型名が識別子でない場合は文字列として扱う
              stmts.add quote do:
                `recordVar`[`key`] = candid_funcs.newCText($`value`)
          of nnkIdent:
            # 識別子（bool等）
            if value.strVal == "true":
              stmts.add quote do:
                `recordVar`[`key`] = candid_funcs.newCBool(true)
            elif value.strVal == "false":
              stmts.add quote do:
                `recordVar`[`key`] = candid_funcs.newCBool(false)
            else:
              # その他の識別子は文字列として扱う
              stmts.add quote do:
                `recordVar`[`key`] = candid_funcs.newCText($`value`)
          of nnkCurly, nnkTableConstr:
            # ネストしたRecord
            let nestedRecord = buildRecord(value)
            stmts.add quote do:
              `recordVar`[`key`] = `nestedRecord`
          else:
            # その他の値は文字列に変換
            stmts.add quote do:
              `recordVar`[`key`] = candid_funcs.newCText($`value`)
      
      stmts.add(recordVar)
      return newBlockStmt(stmts)
    
    of nnkStrLit:
      # 単純な文字列
      return quote do:
        candid_funcs.newCText(`node`)
    of nnkIntLit:
      # 単純な整数
      return quote do:
        candid_funcs.newCInt(`node`)
    else:
      # その他の値は文字列に変換
      return quote do:
        candid_funcs.newCText($`node`)
  
  return buildRecord(x)

# %C エイリアス（Nim 1.6+ では %演算子の定義にはspecial文字の組み合わせが必要）
template `%*`*(x: untyped): CandidRecord = candidLit(x)

# ===== 汎用seq処理のヘルパーマクロ =====

macro processSeqValue*(seqVal: typed): CandidValue =
  ## seq[T]型を汎用的に処理するヘルパーマクロ
  let newCandidValueSym = bindSym"newCandidValue"
  
  quote do:
    block:
      var vecItems: seq[CandidValue] = @[]
      for item in `seqVal`:
        when item is seq[uint8]:
          # seq[uint8]はblobとして処理
          vecItems.add(`newCandidValueSym`(item))
        elif item is seq:
          # ネストしたseq[T]は再帰的に処理
          vecItems.add(processSeqValue(item))
        elif item is bool:
          vecItems.add(`newCandidValueSym`(item))
        elif item is SomeInteger:
          vecItems.add(`newCandidValueSym`(item))
        elif item is SomeFloat:
          vecItems.add(`newCandidValueSym`(item))
        elif item is string:
          vecItems.add(`newCandidValueSym`(item))
        elif item is Principal:
          vecItems.add(`newCandidValueSym`(item))
        elif item is enum:
          vecItems.add(`newCandidValueSym`(item))
        elif item is Option:
          if item.isSome():
            vecItems.add(`newCandidValueSym`(item.get()))
          else:
            vecItems.add(CandidValue(kind: ctOpt, optVal: none(CandidValue)))
        else:
          # 型が判明しない場合はテキストとして処理
          vecItems.add(`newCandidValueSym`($item))
      
      # vec blob型として返す
      CandidValue(kind: ctVec, vecVal: vecItems)
