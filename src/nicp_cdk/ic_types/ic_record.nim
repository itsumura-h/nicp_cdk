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
  cv.intVal.int

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

proc newCPrincipal*(principalId: string): CandidRecord =
  ## Principal CandidRecordを作成
  CandidRecord(kind: ckPrincipal, principalId: principalId)

proc newCOptionNone*(): CandidRecord =
  ## None Option CandidRecordを作成
  CandidRecord(kind: ckOption, optVal: none(CandidRecord))

proc asSome*(value: CandidRecord): CandidRecord =
  ## Some Option CandidRecordを作成
  CandidRecord(kind: ckOption, optVal: some(value))

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
  ## CandidRecordリテラル構築マクロ
  ## 
  ## サポートする構文:
  ## - 基本型: bool, 整数, 浮動小数点, string
  ## - Principal: Principal型の変数
  ## - Blob: seq[uint8]型の変数
  ## - Array: [elem1, elem2, ...]
  ## - Record: {key1: value1, key2: value2, ...}
  ## - Option: some(value) または none(Type)
  ## - 明示的構築: newCNull(), newCArray(), newCRecord(), newCBlob(), newCPrincipal(), newCVariant(), newCFunc(), newCService()
  ## - Null: nil または newCNull()
  
  proc buildCandidValue(node: NimNode): NimNode =
    case node.kind:
    # リテラル値
    of nnkIntLit, nnkInt8Lit, nnkInt16Lit, nnkInt32Lit, nnkInt64Lit,
       nnkUIntLit, nnkUInt8Lit, nnkUInt16Lit, nnkUInt32Lit, nnkUInt64Lit:
      newCall(bindSym"newCIntRecord", node)
    
    of nnkFloatLit, nnkFloat32Lit, nnkFloat64Lit:
      newCall(bindSym"newCFloat64Record", node)
    
    of nnkStrLit:
      newCall(bindSym"newCTextRecord", node)
    
    # nil値をnewCNull()として解釈
    of nnkNilLit:
      newCall(bindSym"newCNull")
    
    of nnkIdent:
      if node.strVal == "true":
        newCall(bindSym"newCBoolRecord", newLit(true))
      elif node.strVal == "false":
        newCall(bindSym"newCBoolRecord", newLit(false))
      elif node.strVal == "cnull":
        newCall(bindSym"newCNull")
      else:
        # 変数参照の場合は実行時に型チェック
        let varName = node
        quote do:
          when `varName` is CandidRecord:
            `varName`
          elif `varName` is bool:
            newCBoolRecord(`varName`)
          elif `varName` is SomeInteger:
            newCIntRecord(`varName`.int64)
          elif `varName` is SomeFloat:
            newCFloat64Record(`varName`.float)
          elif `varName` is string:
            newCTextRecord(`varName`)
          elif `varName` is seq[uint8]:
            newCBlobRecord(`varName`)
          elif `varName` is Principal:
            newCPrincipal(`varName`.value)
          elif `varName` is enum:
            newCVariantRecord($`varName`)
          elif `varName` is Option:
            if `varName`.isSome():
              asSome(candidLit(`varName`.get()))
            else:
              newCOptionNone()
          elif `varName` is type(nil):
            newCNull()
          else:
            {.error: "Unsupported type for candidLit macro".}
    
    # 配列リテラル [elem1, elem2, ...]
    of nnkBracket:
      let arrayVar = genSym(nskVar, "arr")
      result = newStmtList()
      result.add(newVarStmt(arrayVar, newCall(bindSym"newCArrayRecord")))
      for elem in node:
        result.add(newCall(bindSym"add", arrayVar, buildCandidValue(elem)))
      result.add(arrayVar)
      return result
    
    # レコードリテラル {key1: value1, key2: value2, ...}
    of nnkTableConstr:
      let recordVar = genSym(nskVar, "rec")
      result = newStmtList()
      result.add(newVarStmt(recordVar, newCall(bindSym"newCRecordEmpty")))
      for pair in node:
        if pair.kind == nnkExprColonExpr and pair.len == 2:
          let key = pair[0]
          let value = pair[1]
          # キーは文字列リテラルまたは識別子
          let keyStr = if key.kind == nnkStrLit:
                        key
                       elif key.kind == nnkIdent:
                        newLit(key.strVal)
                       else:
                        error("Record key must be string literal or identifier", key)
                        newLit("")
          result.add(newAssignment(
            newNimNode(nnkBracketExpr).add(recordVar, keyStr),
            buildCandidValue(value)
          ))
        else:
          error("Invalid record syntax", pair)
      result.add(recordVar)
      return result

    # 関数呼び出し（none(Type), some(value)など）
    of nnkCall:
      if node.len >= 1 and node[0].kind == nnkIdent:
        if node[0].strVal == "none":
          # none(Type)の場合
          newCall(bindSym"newCOptionNone")
        elif node[0].strVal == "some" and node.len == 2:
          # some(value)の場合
          newCall(bindSym"asSome", buildCandidValue(node[1]))
        else:
          # その他の関数呼び出しは実行時処理
          quote do:
            let val = `node`
            when val is CandidRecord:
              val
            elif val is bool:
              newCBoolRecord(val)
            elif val is SomeInteger:
              newCIntRecord(val.int64)
            elif val is SomeFloat:
              newCFloat64Record(val.float)
            elif val is string:
              newCTextRecord(val)
            elif val is seq[uint8]:
              newCBlobRecord(val)
            elif val is Principal:
              newCPrincipal(val.value)
            elif val is enum:
              newCVariantRecord($val)
            elif val is Option:
              if val.isSome():
                asSome(candidLit(val.get()))
              else:
                newCOptionNone()
            else:
              {.error: "Unsupported type for candidLit macro".}
      else:
        # その他の複雑な式は実行時処理
        quote do:
          let val = `node`
          when val is CandidRecord:
            val
          elif val is bool:
            newCBool(val)
          elif val is SomeInteger:
            newCInt(val.int64)
          elif val is SomeFloat:
            newCFloat64(val.float)
          elif val is string:
            newCText(val)
          elif val is seq[uint8]:
            newCBlob(val)
          elif val is Principal:
            newCPrincipal(val.value)
          elif val is enum:
            newCVariant($val)
          elif val is Option:
            if val.isSome():
              asSome(candidLit(val.get()))
            else:
              newCOptionNone()
          else:
            {.error: "Unsupported type for candidLit macro".}

    # その他の式（変数参照、複雑な式など）
    else:
      # 実行時に型判定
      quote do:
        let val = `node`
        when val is CandidRecord:
          val
        elif val is bool:
          newCBool(val)
        elif val is SomeInteger:
          newCInt(val.int64)
        elif val is SomeFloat:
          newCFloat64(val.float)
        elif val is string:
          newCText(val)
        elif val is seq[uint8]:
          newCBlob(val)
        elif val is Principal:
          newCPrincipal(val.value)
        elif val is enum:
          newCVariant($val)
        elif val is Option:
          if val.isSome():
            asSome(candidLit(val.get()))
          else:
            newCOptionNone()
        else:
          {.error: "Unsupported type for candidLit macro".}
  
  buildCandidValue(x)

# %C エイリアス（Nim 1.6+ では %演算子の定義にはspecial文字の組み合わせが必要）
template `%*`*(x: untyped): CandidRecord = candidLit(x)
