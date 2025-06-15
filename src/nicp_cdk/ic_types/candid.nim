# Candidメッセージのエンコード・デコード機能
# このファイルは分割されたモジュールを再エクスポートします

import std/sequtils
import std/options
import std/strutils
import std/tables
import ./candid_types
import ./candid_message/candid_message_types
import ./candid_message/candid_decode
import ./candid_message/candid_encode

# 型をすべてエクスポート
export candid_types

# デコード機能をエクスポート
export candid_decode

# エンコード機能をエクスポート  
export candid_encode

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
  of ctBlob:
    result = "blob \"" & value.blobVal.mapIt(it.toHex()).join("") & "\""
  of ctRecord:
    result = "record {"
    var first = true
    for fieldName, fieldValue in value.recordVal.fields:
      if not first:
        result.add("; ")
      result.add(fieldName & " = " & $fieldValue)
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
