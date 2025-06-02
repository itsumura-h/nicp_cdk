import std/tables
import std/strutils
import std/strformat
import std/options
import std/base64
import std/hashes
import std/macros
import ./ic_principal

type
  CandidKind* = enum
    ckNull, ckBool, ckInt, ckFloat32, ckFloat64, ckText, ckBlob,
    ckRecord, ckVariant, ckOption, ckPrincipal, ckFunc, ckService, ckArray

  CandidVariant* = object
    ## Variant型の値を保持するオブジェクト
    tag*: string         ## Variantのタグ名
    value*: CandidValue  ## Variantの保持する値

  CandidValue* = ref object
    case kind*: CandidKind
    of ckNull:
      discard  # 値を持たない
    of ckBool:
      boolVal*: bool
    of ckInt:
      intVal*: int64  # TODO: BigIntサポート時は BigInt に変更
    of ckFloat32:
      f32Val*: float32
    of ckFloat64:
      f64Val*: float
    of ckText:
      strVal*: string
    of ckBlob:
      bytesVal*: seq[uint8]
    of ckRecord:
      fields*: OrderedTable[string, CandidValue]
    of ckVariant:
      variantVal*: CandidVariant
    of ckOption:
      optVal*: Option[CandidValue]
    of ckPrincipal:
      principalId*: string
    of ckFunc:
      funcRef*: tuple[principal: string, methodName: string]
    of ckService:
      serviceId*: string
    of ckArray:
      elems*: seq[CandidValue]

# ===== コンストラクタ関数 =====

proc newCNull*(): CandidValue =
  ## Null値を表すCandidValueを生成
  CandidValue(kind: ckNull)

proc newCBool*(b: bool): CandidValue =
  ## ブール値からCandidValueを生成
  CandidValue(kind: ckBool, boolVal: b)

proc newCInt*(i: int64): CandidValue =
  ## 整数からCandidValueを生成
  CandidValue(kind: ckInt, intVal: i)

proc newCInt*(i: int): CandidValue =
  ## 整数からCandidValueを生成
  CandidValue(kind: ckInt, intVal: i.int64)

proc newCFloat32*(f: float32): CandidValue =
  ## 単精度浮動小数点からCandidValueを生成
  CandidValue(kind: ckFloat32, f32Val: f)

proc newCFloat64*(f: float): CandidValue =
  ## 倍精度浮動小数点からCandidValueを生成
  CandidValue(kind: ckFloat64, f64Val: f)

proc newCText*(s: string): CandidValue =
  ## テキストからCandidValueを生成
  CandidValue(kind: ckText, strVal: s)

proc newCBlob*(bytes: seq[uint8]): CandidValue =
  ## バイト列からCandidValueを生成
  CandidValue(kind: ckBlob, bytesVal: bytes)

proc newCRecord*(): CandidValue =
  ## 空のレコードを生成
  CandidValue(kind: ckRecord, fields: initOrderedTable[string, CandidValue]())

proc newCArray*(): CandidValue =
  ## 空の配列を生成
  CandidValue(kind: ckArray, elems: @[])

proc newCVariant*(tag: string, val: CandidValue): CandidValue =
  ## 指定タグ・値のVariantを生成
  CandidValue(kind: ckVariant, variantVal: CandidVariant(tag: tag, value: val))

proc newCVariant*(tag: string): CandidValue =
  ## 値を持たないVariantケースを生成
  CandidValue(kind: ckVariant, variantVal: CandidVariant(tag: tag, value: newCNull()))

proc newCOption*(val: CandidValue): CandidValue =
  ## Some値を持つOptionを生成
  CandidValue(kind: ckOption, optVal: some(val))

proc newCOptionNone*(): CandidValue =
  ## Noneを生成
  CandidValue(kind: ckOption, optVal: none(CandidValue))

proc newCPrincipal*(text: string): CandidValue =
  ## Principal ID文字列からCandidValueを生成
  CandidValue(kind: ckPrincipal, principalId: text)

proc newCFunc*(principal: string, methodName: string): CandidValue =
  ## Func参照を生成
  CandidValue(kind: ckFunc, funcRef: (principal: principal, methodName: methodName))

proc newCService*(principal: string): CandidValue =
  ## Service参照を生成
  CandidValue(kind: ckService, serviceId: principal)

# ===== アクセサ関数 =====

proc getInt*(cv: CandidValue): int64 =
  ## 整数値を取得
  if cv.kind != ckInt:
    raise newException(ValueError, &"Expected Int, got {cv.kind}")
  cv.intVal

proc getFloat32*(cv: CandidValue): float32 =
  ## 単精度浮動小数点値を取得
  if cv.kind != ckFloat32:
    raise newException(ValueError, &"Expected Float32, got {cv.kind}")
  cv.f32Val

proc getFloat64*(cv: CandidValue): float =
  ## 倍精度浮動小数点値を取得
  if cv.kind != ckFloat64:
    raise newException(ValueError, &"Expected Float64, got {cv.kind}")
  cv.f64Val

proc getBool*(cv: CandidValue): bool =
  ## ブール値を取得
  if cv.kind != ckBool:
    raise newException(ValueError, &"Expected Bool, got {cv.kind}")
  cv.boolVal

proc getStr*(cv: CandidValue): string =
  ## 文字列値を取得
  if cv.kind != ckText:
    raise newException(ValueError, &"Expected Text, got {cv.kind}")
  cv.strVal

proc getBytes*(cv: CandidValue): seq[uint8] =
  ## バイト列を取得
  if cv.kind != ckBlob:
    raise newException(ValueError, &"Expected Blob, got {cv.kind}")
  cv.bytesVal

proc getArray*(cv: CandidValue): seq[CandidValue] =
  ## 配列の要素を取得
  if cv.kind != ckArray:
    raise newException(ValueError, &"Expected Array, got {cv.kind}")
  cv.elems

# ===== インデックス演算子（レコード用） =====

proc `[]`*(cv: CandidValue, key: string): CandidValue =
  ## レコードのフィールドにアクセス（存在しない場合は例外）
  if cv.kind != ckRecord:
    raise newException(ValueError, &"Cannot index {cv.kind} with string key")
  if key notin cv.fields:
    raise newException(KeyError, &"Key '{key}' not found in record")
  cv.fields[key]

proc `[]=`*(cv: CandidValue, key: string, value: CandidValue) =
  ## レコードのフィールドを設定
  if cv.kind != ckRecord:
    raise newException(ValueError, &"Cannot set field on {cv.kind}")
  cv.fields[key] = value

# ===== インデックス演算子（配列用） =====

proc `[]`*(cv: CandidValue, index: int): CandidValue =
  ## 配列の要素にアクセス（存在しない場合は例外）
  if cv.kind != ckArray:
    raise newException(ValueError, &"Cannot index {cv.kind} with integer")
  if index < 0 or index >= cv.elems.len:
    raise newException(IndexDefect, &"Index {index} out of bounds for array of length {cv.elems.len}")
  cv.elems[index]

proc `[]=`*(cv: CandidValue, index: int, value: CandidValue) =
  ## 配列の要素を設定
  if cv.kind != ckArray:
    raise newException(ValueError, &"Cannot set array element on {cv.kind}")
  if index < 0 or index >= cv.elems.len:
    raise newException(IndexDefect, &"Index {index} out of bounds for array of length {cv.elems.len}")
  cv.elems[index] = value

# ===== 安全なアクセス =====

proc contains*(cv: CandidValue, key: string): bool =
  ## レコード内にキーが存在するかチェック
  if cv.kind != ckRecord:
    return false
  key in cv.fields

proc get*(cv: CandidValue, key: string, default: CandidValue = nil): CandidValue =
  ## 安全なフィールド取得（存在しない場合はdefaultを返す）
  if cv.kind != ckRecord or key notin cv.fields:
    return default
  cv.fields[key]

# ===== 配列操作 =====

proc add*(cv: CandidValue, value: CandidValue) =
  ## 配列の末尾に要素を追加
  if cv.kind != ckArray:
    raise newException(ValueError, &"Cannot add element to {cv.kind}")
  cv.elems.add(value)

proc len*(cv: CandidValue): int =
  ## 配列またはレコードの長さを取得
  case cv.kind:
  of ckArray:
    cv.elems.len
  of ckRecord:
    cv.fields.len
  else:
    0

# ===== 削除操作 =====

proc delete*(cv: CandidValue, key: string) =
  ## レコードからフィールドを削除
  if cv.kind != ckRecord:
    raise newException(ValueError, &"Cannot delete field from {cv.kind}")
  cv.fields.del(key)

proc delete*(cv: CandidValue, index: int) =
  ## 配列から要素を削除
  if cv.kind != ckArray:
    raise newException(ValueError, &"Cannot delete element from {cv.kind}")
  if index < 0 or index >= cv.elems.len:
    raise newException(IndexDefect, &"Index {index} out of bounds")
  cv.elems.delete(index)

# ===== Principal/Func関連のヘルパー =====

proc getPrincipal*(cv: CandidValue): Principal =
  ## Principal値をPrincipal型として取得
  if cv.kind != ckPrincipal:
    raise newException(ValueError, &"Expected Principal, got {cv.kind}")
  let p = Principal.fromText(cv.principalId)
  return p

proc getFuncPrincipal*(cv: CandidValue): Principal =
  ## Func値のprincipal部分を取得
  if cv.kind != ckFunc:
    raise newException(ValueError, &"Expected Func, got {cv.kind}")
  let p = Principal.fromText(cv.funcRef.principal)
  return p

proc getFuncMethod*(cv: CandidValue): string =
  ## Func値のmethod部分を取得
  if cv.kind != ckFunc:
    raise newException(ValueError, &"Expected Func, got {cv.kind}")
  cv.funcRef.methodName

proc getService*(cv: CandidValue): string =
  ## Service値を文字列として取得
  if cv.kind != ckService:
    raise newException(ValueError, &"Expected Service, got {cv.kind}")
  cv.serviceId

# ===== Option/Variant専用ヘルパー =====

proc isSome*(cv: CandidValue): bool =
  ## Optionが値を持つかチェック
  cv.kind == ckOption and cv.optVal.isSome()

proc isNone*(cv: CandidValue): bool =
  ## OptionがNoneかチェック
  cv.kind == ckOption and cv.optVal.isNone()

proc getOpt*(cv: CandidValue): CandidValue =
  ## Optionの中身の値を取得（Noneの場合は例外）
  if cv.kind != ckOption:
    raise newException(ValueError, &"Expected Option, got {cv.kind}")
  if cv.optVal.isNone():
    raise newException(ValueError, "Cannot get value from None option")
  cv.optVal.get()

proc getVariant*(cv: CandidValue): CandidVariant =
  ## Variantの内容をCandidVariant型として取得
  if cv.kind != ckVariant:
    raise newException(ValueError, &"Expected Variant, got {cv.kind}")
  cv.variantVal

# ===== フィールド名のハッシュ化関数 =====

proc candidFieldHash*(name: string): uint32 =
  ## Candidフィールド名のハッシュIDを計算
  ## 注意：実際のCandid仕様に準拠したハッシュ関数を実装する必要があります
  ## ここでは簡易版として標準のhash関数を使用
  name.hash().uint32

# ===== JSON風文字列化 =====

proc candidValueToJsonString(cv: CandidValue, indent: int = 0): string

proc indentStr(level: int): string =
  "  ".repeat(level)

proc candidValueToJsonString(cv: CandidValue, indent: int = 0): string =
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
        lines.add(indentStr(indent + 1) & keyStr & ": " & candidValueToJsonString(value, indent + 1))
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
    "{\"" & cv.variantVal.tag & "\": " & candidValueToJsonString(cv.variantVal.value, indent) & "}"
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

proc `$`*(cv: CandidValue): string =
  ## CandidValueをJSON風文字列に変換
  candidValueToJsonString(cv)

# ===== 便利マクロ（JsonNodeの %* に相当） =====

macro candidLit*(x: untyped): CandidValue =
  ## CandidValueリテラル構築マクロ（拡張版）
  ## 
  ## サポートする構文:
  ## - 基本型: bool, 整数, 浮動小数点, string
  ## - Principal: cprincipal("aaaaa-aa")
  ## - Blob: cblob([1, 2, 3]) または cblob(@[1u8, 2u8, 3u8])
  ## - Array: [elem1, elem2, ...]
  ## - Record: {key1: value1, key2: value2, ...}
  ## - Option: csome(value) または cnone()
  ## - Variant: cvariant("tag", value) または cvariant("tag")
  ## - Func: cfunc("principal", "method")
  ## - Service: cservice("principal")
  ## - Null: cnull()
  
  proc buildCandidValue(node: NimNode): NimNode =
    case node.kind:
    # リテラル値
    of nnkIntLit, nnkInt8Lit, nnkInt16Lit, nnkInt32Lit, nnkInt64Lit,
       nnkUIntLit, nnkUInt8Lit, nnkUInt16Lit, nnkUInt32Lit, nnkUInt64Lit:
      newCall(bindSym"newCInt", node)
    
    of nnkFloatLit, nnkFloat32Lit, nnkFloat64Lit:
      newCall(bindSym"newCFloat64", node)
    
    of nnkStrLit:
      newCall(bindSym"newCText", node)
    
    # nil値をnewCNull()として解釈
    of nnkNilLit:
      newCall(bindSym"newCNull")
    
    of nnkIdent:
      if node.strVal == "true":
        newCall(bindSym"newCBool", newLit(true))
      elif node.strVal == "false":
        newCall(bindSym"newCBool", newLit(false))
      elif node.strVal == "cnull":
        newCall(bindSym"newCNull")
      else:
        # 変数参照の場合は実行時に型チェック
        let varName = node
        quote do:
          when `varName` is bool:
            newCBool(`varName`)
          elif `varName` is SomeInteger:
            newCInt(`varName`.int64)
          elif `varName` is SomeFloat:
            newCFloat64(`varName`.float)
          elif `varName` is string:
            newCText(`varName`)
          elif `varName` is seq[uint8]:
            newCBlob(`varName`)
          elif `varName` is CandidValue:
            `varName`
          elif `varName` is Principal:
            newCPrincipal(`varName`.value)
          elif `varName` is Option:
            if `varName`.isSome():
              newCOption(candidLit(`varName`.get()))
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
      result.add(newVarStmt(arrayVar, newCall(bindSym"newCArray")))
      for elem in node:
        result.add(newCall(bindSym"add", arrayVar, buildCandidValue(elem)))
      result.add(arrayVar)
      return result
    
    # レコードリテラル {key1: value1, key2: value2, ...}
    of nnkTableConstr:
      let recordVar = genSym(nskVar, "rec")
      result = newStmtList()
      result.add(newVarStmt(recordVar, newCall(bindSym"newCRecord")))
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
    
    # 関数呼び出し (cprincipal, csome, cnone, cvariant, cfunc, cservice, cblob)
    of nnkCall:
      if node.len == 0:
        error("Empty function call", node)
        return newCall(bindSym"newCNull")
      
      let funcName = node[0]
      if funcName.kind == nnkIdent:
        case funcName.strVal:
        of "cprincipal":
          if node.len == 2:
            let arg = node[1]
            if arg.kind == nnkStrLit:
              newCall(bindSym"newCPrincipal", arg)
            else:
              newCall(bindSym"newCPrincipal", arg)
          else:
            error("cprincipal() requires exactly one argument", node)
            newCall(bindSym"newCNull")
        
        of "cblob":
          if node.len == 2:
            # cblob([1, 2, 3]) または cblob(someSeq)
            let arg = node[1]
            if arg.kind == nnkBracket:
              # リテラル配列をseq[uint8]に変換
              var elements = newNimNode(nnkBracket)
              for elem in arg:
                elements.add(newCall(bindSym"uint8", elem))
              newCall(bindSym"newCBlob", newNimNode(nnkPrefix).add(newIdentNode("@"), elements))
            else:
              # 変数の場合はそのまま渡す
              newCall(bindSym"newCBlob", arg)
          else:
            error("cblob() requires exactly one argument", node)
            newCall(bindSym"newCNull")
        
        of "csome":
          if node.len == 2:
            newCall(bindSym"newCOption", buildCandidValue(node[1]))
          else:
            error("csome() requires exactly one argument", node)
            newCall(bindSym"newCNull")
        
        of "cnone":
          if node.len == 1:
            newCall(bindSym"newCOptionNone")
          else:
            error("cnone() takes no arguments", node)
            newCall(bindSym"newCNull")
        
        of "cnull":
          if node.len == 1:
            newCall(bindSym"newCNull")
          else:
            error("cnull() takes no arguments", node)
            newCall(bindSym"newCNull")
        
        of "cvariant":
          if node.len == 2:
            # cvariant("tag") - 値なし
            let tagArg = node[1]
            if tagArg.kind == nnkStrLit:
              newCall(bindSym"newCVariant", tagArg)
            else:
              newCall(bindSym"newCVariant", tagArg)
          elif node.len == 3:
            # cvariant("tag", value)
            let tagArg = node[1]
            let valueArg = node[2]
            let tag = if tagArg.kind == nnkStrLit: tagArg else: tagArg
            newCall(bindSym"newCVariant", tag, buildCandidValue(valueArg))
          else:
            error("cvariant() requires 1 or 2 arguments", node)
            newCall(bindSym"newCNull")
        
        of "cfunc":
          if node.len == 3:
            let principalArg = node[1]
            let methodArg = node[2]
            let principal = if principalArg.kind == nnkStrLit: principalArg else: principalArg
            let methodName = if methodArg.kind == nnkStrLit: methodArg else: methodArg
            newCall(bindSym"newCFunc", principal, methodName)
          else:
            error("cfunc() requires exactly 2 arguments (principal, method)", node)
            newCall(bindSym"newCNull")
        
        of "cservice":
          if node.len == 2:
            let arg = node[1]
            if arg.kind == nnkStrLit:
              newCall(bindSym"newCService", arg)
            else:
              newCall(bindSym"newCService", arg)
          else:
            error("cservice() requires exactly one argument", node)
            newCall(bindSym"newCNull")
        
        # 標準ライブラリのOption型サポート
        of "some":
          if node.len == 2:
            newCall(bindSym"newCOption", buildCandidValue(node[1]))
          else:
            error("some() requires exactly one argument", node)
            newCall(bindSym"newCNull")
        
        of "none":
          # none(Type) または none() の両方に対応
          newCall(bindSym"newCOptionNone")
        
        else:
          # 通常の関数呼び出しまたは式
          # 実行時に型判定
          quote do:
            let val = `node`
            when val is bool:
              newCBool(val)
            elif val is SomeInteger:
              newCInt(val.int64)
            elif val is SomeFloat:
              newCFloat64(val.float)
            elif val is string:
              newCText(val)
            elif val is seq[uint8]:
              newCBlob(val)
            elif val is CandidValue:
              val
            elif val is Principal:
              newCPrincipal(val.toText())
            elif val is Option:
              if val.isSome():
                newCOption(candidLit(val.get()))
              else:
                newCOptionNone()
            else:
              {.error: "Unsupported type for candidLit macro".}
      else:
        error("Function name must be identifier", funcName)
        newCall(bindSym"newCNull")
    
    # ドット記法による関数呼び出し ("Ali".some のような構文)
    of nnkDotExpr:
      if node.len == 2:
        let obj = node[0]
        let methodName = node[1]
        if methodName.kind == nnkIdent:
          case methodName.strVal:
          of "some":
            # obj.some => csome(obj)
            newCall(bindSym"newCOption", buildCandidValue(obj))
          else:
            # その他のドット記法は実行時に評価
            quote do:
              let val = `node`
              when val is bool:
                newCBool(val)
              elif val is SomeInteger:
                newCInt(val.int64)
              elif val is SomeFloat:
                newCFloat64(val.float)
              elif val is string:
                newCText(val)
              elif val is seq[uint8]:
                newCBlob(val)
              elif val is CandidValue:
                val
              elif val is Principal:
                newCPrincipal(val.toText())
              elif val is Option:
                if val.isSome():
                  newCOption(candidLit(val.get()))
                else:
                  newCOptionNone()
              else:
                {.error: "Unsupported type for candidLit macro".}
        else:
          # メソッド名が識別子でない場合は実行時評価
          quote do:
            let val = `node`
            when val is bool:
              newCBool(val)
            elif val is SomeInteger:
              newCInt(val.int64)
            elif val is SomeFloat:
              newCFloat64(val.float)
            elif val is string:
              newCText(val)
            elif val is seq[uint8]:
              newCBlob(val)
            elif val is CandidValue:
              val
            elif val is Principal:
              newCPrincipal(val.toText())
            elif val is Option:
              if val.isSome():
                newCOption(candidLit(val.get()))
              else:
                newCOptionNone()
            else:
              {.error: "Unsupported type for candidLit macro".}
      else:
        # 不正なドット記法は実行時評価
        quote do:
          let val = `node`
          when val is bool:
            newCBool(val)
          elif val is SomeInteger:
            newCInt(val.int64)
          elif val is SomeFloat:
            newCFloat64(val.float)
          elif val is string:
            newCText(val)
          elif val is seq[uint8]:
            newCBlob(val)
          elif val is CandidValue:
            val
          elif val is Principal:
            newCPrincipal(val.toText())
          elif val is Option:
            if val.isSome():
              newCOption(candidLit(val.get()))
            else:
              newCOptionNone()
          else:
            {.error: "Unsupported type for candidLit macro".}
    
    # その他の式（変数参照、複雑な式など）
    else:
      # 実行時に型判定
      quote do:
        let val = `node`
        when val is bool:
          newCBool(val)
        elif val is SomeInteger:
          newCInt(val.int64)
        elif val is SomeFloat:
          newCFloat64(val.float)
        elif val is string:
          newCText(val)
        elif val is seq[uint8]:
          newCBlob(val)
        elif val is CandidValue:
          val
        elif val is Principal:
          newCPrincipal(val.toText())
        elif val is Option:
          if val.isSome():
            newCOption(candidLit(val.get()))
          else:
            newCOptionNone()
        else:
          {.error: "Unsupported type for candidLit macro".}
  
  buildCandidValue(x)

# %C エイリアス（Nim 1.6+ では %演算子の定義にはspecial文字の組み合わせが必要）
template `%*`*(x: untyped): CandidValue = candidLit(x)

# ===== 型判定ヘルパー =====

proc isNull*(cv: CandidValue): bool = cv.kind == ckNull
proc isBool*(cv: CandidValue): bool = cv.kind == ckBool
proc isInt*(cv: CandidValue): bool = cv.kind == ckInt
proc isFloat32*(cv: CandidValue): bool = cv.kind == ckFloat32
proc isFloat64*(cv: CandidValue): bool = cv.kind == ckFloat64
proc isText*(cv: CandidValue): bool = cv.kind == ckText
proc isBlob*(cv: CandidValue): bool = cv.kind == ckBlob
proc isRecord*(cv: CandidValue): bool = cv.kind == ckRecord
proc isArray*(cv: CandidValue): bool = cv.kind == ckArray
proc isVariant*(cv: CandidValue): bool = cv.kind == ckVariant
proc isOption*(cv: CandidValue): bool = cv.kind == ckOption
proc isPrincipal*(cv: CandidValue): bool = cv.kind == ckPrincipal
proc isFunc*(cv: CandidValue): bool = cv.kind == ckFunc
proc isService*(cv: CandidValue): bool = cv.kind == ckService
