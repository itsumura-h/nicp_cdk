import ../ic_types/ic_principal
import ../ic_types/candid_types
import std/options
import std/asyncfutures
import ../ic0/ic0
import ../ic_types/candid_message/candid_encode
import ../ic_types/candid_message/candid_decode

type ManagementCanister* = object

proc publicKey*(_:type ManagementCanister, arg: EcdsaPublicKeyArgs, onReply: proc(result: EcdsaPublicKeyResult), onReject: proc(error: string)) =
  proc onReplyWrapper(env: uint32) {.exportc.} =
    let size = ic0_msg_arg_data_size()
    var buf = newSeq[uint8](size)
    ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
    
    let result = decodeCandidMessage(buf, EcdsaPublicKeyResult)
    onReply(result)

  proc onRejectWrapper(env: uint32) {.exportc.} =
    let err_size = ic0_msg_arg_data_size()
    var err_buf = newSeq[uint8](err_size)
    ic0_msg_arg_data_copy(ptrToInt(addr err_buf[0]), 0, err_size)
    let msg = "call failed: " & $err_buf
    onReject(msg)

  let mgmtPrincipalBytes: seq[uint8] = @[]
  let destPtr   = if mgmtPrincipalBytes.len > 0: mgmtPrincipalBytes[0].addr else: nil
  let destLen   = mgmtPrincipalBytes.len

  let methodName = "ecdsa_public_key".cstring
  ic0_call_new(
    callee_src = cast[int](destPtr),
    callee_size = destLen,
    name_src = cast[int](methodName),
    name_size = methodName.len,
    reply_fun = cast[int](onReplyWrapper),
    reply_env = 0,
    reject_fun = cast[int](onRejectWrapper),
    reject_env = 0
  )

  let candidValue = newCandidRecord(arg)
  let encoded = encodeCandidMessage(@[candidValue])
  ic0_call_data_append(ptrToInt(addr encoded[0]), encoded.len)
  
  let err = ic0_call_perform()
  if err != 0:
    let msg = "call_perform failed"
    onReject(msg)

proc signWithEcdsa*(_:type ManagementCanister, arg: candid_types.SignWithEcdsaArgs, onReply: proc(result: SignWithEcdsaResult), onReject: proc(error: string)) =
  proc onReplyWrapper(env: uint32) {.exportc.} =
    let size = ic0_msg_arg_data_size()
    var buf = newSeq[uint8](size)
    ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
    
    let result = decodeCandidMessage(buf, SignWithEcdsaResult)
    onReply(result)

  proc onRejectWrapper(env: uint32) {.exportc.} =
    let err_size = ic0_msg_arg_data_size()
    var err_buf = newSeq[uint8](err_size)
    ic0_msg_arg_data_copy(ptrToInt(addr err_buf[0]), 0, err_size)
    let msg = "call failed: " & $err_buf
    onReject(msg)

  let mgmtPrincipalBytes: seq[uint8] = @[]
  let destPtr   = if mgmtPrincipalBytes.len > 0: mgmtPrincipalBytes[0].addr else: nil
  let destLen   = mgmtPrincipalBytes.len

  let methodName = "sign_with_ecdsa".cstring
  ic0_call_new(
    callee_src = cast[int](destPtr),
    callee_size = destLen,
    name_src = cast[int](methodName),
    name_size = methodName.len,
    reply_fun = cast[int](onReplyWrapper),
    reply_env = 0,
    reject_fun = cast[int](onRejectWrapper),
    reject_env = 0
  )

  let candidValue = newCandidRecord(arg)
  let encoded = encodeCandidMessage(@[candidValue])
  ic0_call_data_append(ptrToInt(addr encoded[0]), encoded.len)
  
  let err = ic0_call_perform()
  if err != 0:
    let msg = "call_perform failed"
    onReject(msg)

let asyncManagementCanister* = ManagementCanister()