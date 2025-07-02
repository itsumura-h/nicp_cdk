import ../ic0/ic0
import ../ic_types/ic_principal
import ../ic_types/candid_types
import ../ic_types/candid_message/candid_encode
import ./async_management_canister


# Callback to handle the result of `ecdsa_public_key` call
proc onPublicKeyReply(env: uint32) {.exportc.} =
  echo "=== onPublicKeyReply start ==="
  let size = ic0_msg_arg_data_size() # Get reply data size
  echo "size: ", $size
  var buf = newSeq[uint8](size)              
  # Copy reply data (public key and chain code)
  ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
  echo "buf: ", buf.toString()
  # Note: buf contains the Candid encoding of EcdsaPublicKeyResult here.
  # Decode public key bytes and chain code bytes from buf as needed.
  # For this example, simply forward to the caller.
  ic0_msg_reply_data_append(ptrToInt(addr buf[0]), size) # Set data to reply message
  ic0_msg_reply()         
  echo "=== onPublicKeyReply end ==="
  # Return reply to the original caller


# Callback to handle the rejection of `ecdsa_public_key` call
proc onPublicKeyReject(env: uint32) {.exportc.} =
  echo "=== onPublicKeyReject start ==="
  let err_size = ic0_msg_arg_data_size()
  var err_buf = newSeq[uint8](err_size)
  ic0_msg_arg_data_copy(ptrToInt(addr err_buf[0]), 0, err_size) # Get error content
  ic0_trap(cast[int](err_buf.addr), err_size)
  echo "=== onPublicKeyReject end ==="


proc fetchECDSAPublicKey(arg: EcdsaPublicKeyArgs) =
  echo "=== fetchECDSAPublicKey start ==="
  ## 1. Explicitly specify the Principal of the management canister "aaaaa-aa" (empty byte sequence)
  let mgmtPrincipalBytes: seq[uint8] = @[] # The binary of "aaaaa-aa" is empty
  let destPtr   = if mgmtPrincipalBytes.len > 0: mgmtPrincipalBytes[0].addr else: nil
  let destLen   = mgmtPrincipalBytes.len # 0

  ## 2. Set up the call to the management canister
  let methodName = "ecdsa_public_key".cstring
  ic0_call_new(
    callee_src = cast[int](destPtr),
    callee_size = destLen,
    name_src = cast[int](methodName),
    name_size = methodName.len,
    reply_fun = cast[int](onPublicKeyReply),
    reply_env = 0,
    reject_fun = cast[int](onPublicKeyReject),
    reject_env = 0
  )

  ## 3. Append argument data and perform the call
  let candidValue = newCandidRecord(arg)
  let encoded = encodeCandidMessage(@[candidValue])
  ic0_call_data_append(ptrToInt(addr encoded[0]), encoded.len)
  let err = ic0_call_perform()
  if err != 0:
    let msg = "call_perform failed"
    ic0_trap(cast[int](msg[0].addr), msg.len)
  echo "=== fetchECDSAPublicKey end ==="


type ManagementCanister* = object

proc publicKey*(_:type ManagementCanister, arg: EcdsaPublicKeyArgs) =
  echo "=== management_canister.nim publicKey start ==="
  fetchECDSAPublicKey(arg)
  let n = ic0_msg_arg_data_size()
  var data = newSeq[byte](n)
  ic0_msg_arg_data_copy(ptrToInt(addr data[0]), 0, n)
  echo "data: ", data.toString()
  echo "=== management_canister.nim publicKey end ==="
