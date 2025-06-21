import std/options
import ./ic0/ic0
import ./ic_types/candid_types
import ./ic_types/candid_message/candid_encode
import ./ic_types/ic_principal
import ./ic_api


proc reply*() =
  let value = newCandidNull()
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()

proc reply*(msg: bool) =
  let value = newCandidBool(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: int) =
  let value = newCandidInt(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: int8) =
  let value = newCandidInt8(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: int16) =
  let value = newCandidInt16(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: int32) =
  let value = newCandidInt32(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: int64) =
  let value = newCandidInt64(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: uint) =
  let value = newCandidNat(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: uint8) =
  let value = newCandidNat8(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: uint16) =
  let value = newCandidNat16(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: uint32) =
  let value = newCandidNat32(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: float32) =
  let value = newCandidFloat32(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()

proc reply*(msg: float64) =
  let value = newCandidFloat64(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()

proc reply*(msg: string) =
  let value = newCandidText(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: Principal) =
  let value = newCandidPrincipal(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


# proc reply*[T](msg: Table[string, T]) =
#   let value = newCandidRecord(msg)
#   let encoded = encodeCandidMessage(@[value])
#   ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
#   ic0_msg_reply()


proc reply*(msg: CandidRecord) =
  let value = newCandidRecord(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: uint64) =
  let value = newCandidNat64(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: seq[uint8]) =
  let value = newCandidBlob(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*[T](msg: Option[T]) =
  ## Reply with an optional value
  let optValue = if msg.isSome():
    some(newCandidOpt(msg))
  else:
    none(CandidValue)
  let value = newCandidOpt(optValue)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: seq[CandidValue]) =
  ## Reply with a vector of CandidValue
  let value = newCandidVec(msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: CandidVariant) =
  ## Reply with a variant value
  let value = CandidValue(kind: ctVariant, variantVal: msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*(msg: CandidFunc) =
  ## Reply with a function value
  let value = CandidValue(kind: ctFunc, funcVal: msg)
  let encoded = encodeCandidMessage(@[value])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


# ================================================================================
# Enum型サポート関数
# ================================================================================

proc reply*(msg: CandidValue) =
  ## Reply with a CandidValue directly
  let encoded = encodeCandidMessage(@[msg])
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()


proc reply*[T: enum](enumValue: T) =
  ## Reply with an enum value (automatically converted to Variant)
  try:
    let value = newCandidVariant(enumValue)  # Enum→Variant変換
    let encoded = encodeCandidMessage(@[value])
    ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
    ic0_msg_reply()
  except ValueError as e:
    # Enum変換エラーの場合、エラーメッセージを返す
    let errorText = "Enum conversion error: " & e.msg
    let errorValue = newCandidText(errorText)
    let encoded = encodeCandidMessage(@[errorValue])
    ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
    ic0_msg_reply()
