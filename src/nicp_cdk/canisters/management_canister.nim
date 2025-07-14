import std/options
import std/asyncfutures
import std/tables
import ../ic0/ic0
import ../ic_types/candid_types
import ../ic_types/ic_principal
import ../ic_types/ic_record
import ../ic_types/candid_message/candid_encode
import ../ic_types/candid_message/candid_decode
import ../ic_types/candid_message/candid_message_types

# ================================================================================
# ECDSA related type definitions
# ================================================================================
type
  EcdsaCurve* {.pure.} = enum
    secp256k1 = 0
    secp256r1 = 1

  EcdsaKeyId* = object
    curve*: EcdsaCurve
    name*: string

  EcdsaPublicKeyArgs* = object
    canister_id*: Option[Principal]
    derivation_path*: seq[seq[uint8]]
    key_id*: EcdsaKeyId
  
  EcdsaPublicKeyResult* = object
    public_key*: seq[uint8]
    chain_code*: seq[uint8]

  EcdsaSignArgs* = object
    message_hash*: seq[uint8]
    derivation_path*: seq[seq[uint8]]
    key_id*: EcdsaKeyId

  SignWithEcdsaResult* = object
    signature*: seq[uint8]

# ================================================================================
# Conversion functions from CandidValue to ECDSA types
# ================================================================================
proc candidValueToEcdsaPublicKeyResult(candidValue: CandidValue): EcdsaPublicKeyResult =
  ## Converts a CandidValue to EcdsaPublicKeyResult
  if candidValue.kind != ctRecord:  
    raise newException(CandidDecodeError, "Expected record type for EcdsaPublicKeyResult")

  let recordVal = candidValueToCandidRecord(candidValue)
  let publicKeyVal = recordVal["public_key"].getBlob()
  let chainCodeVal = recordVal["chain_code"].getBlob()

  return EcdsaPublicKeyResult(
    public_key: publicKeyVal,
    chain_code: chainCodeVal
  )

proc candidValueToSignWithEcdsaResult(candidValue: CandidValue): SignWithEcdsaResult =
  ## Converts a CandidValue to SignWithEcdsaResult
  if candidValue.kind != ctRecord:  
    raise newException(CandidDecodeError, "Expected record type for SignWithEcdsaResult")

  let recordVal = candidValueToCandidRecord(candidValue)
  let signatureVal = recordVal["signature"].getBlob()

  return SignWithEcdsaResult(
    signature: signatureVal
  )


# ================================================================================
# Global callback functions
# ================================================================================
proc onCallPublicKeyCanister(env: uint32) {.exportc.} =
  ## Success callback: Restore Future from env and complete it
  let fut = cast[Future[EcdsaPublicKeyResult]](env)
  if fut == nil or fut.finished:
    return
  
  try:
    let size = ic0_msg_arg_data_size()
    var buf = newSeq[uint8](size)
    ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
    let decoded = decodeCandidMessage(buf)
    let publicKeyResult = candidValueToEcdsaPublicKeyResult(decoded.values[0])
    complete(fut, publicKeyResult)
  except Exception as e:
    fail(fut, e)


proc onCallSignCanister(env: uint32) {.exportc.} =
  ## Success callback: Restore Future from env and complete it
  let fut = cast[Future[SignWithEcdsaResult]](env)
  if fut == nil or fut.finished:
    return
  
  try:
    let size = ic0_msg_arg_data_size()
    var buf = newSeq[uint8](size)
    ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
    let decoded = decodeCandidMessage(buf)
    let signResult = candidValueToSignWithEcdsaResult(decoded.values[0])
    complete(fut, signResult)
  except Exception as e:
    fail(fut, e)


proc onCallPublicKeyReject(env: uint32) {.exportc.} =
  ## Failure callback for public key: Restore Future from env and fail it
  let fut = cast[Future[EcdsaPublicKeyResult]](env)
  if fut == nil or fut.finished:
    return
  # reject コールバック内では ic0_msg_arg_data_size は使用できない
  let msg = "ECDSA public key call was rejected by the management canister"
  fail(fut, newException(ValueError, msg))


proc onCallSignReject(env: uint32) {.exportc.} =
  ## Failure callback for sign: Restore Future from env and fail it
  let fut = cast[Future[SignWithEcdsaResult]](env)
  if fut == nil or fut.finished:
    return
  # reject コールバック内では ic0_msg_arg_data_size は使用できない
  let msg = "ECDSA sign call was rejected by the management canister"
  fail(fut, newException(ValueError, msg))


# ================================================================================
# Management Canister API
# ================================================================================
type ManagementCanister* = object

proc publicKey*(_:type ManagementCanister, arg: EcdsaPublicKeyArgs): Future[EcdsaPublicKeyResult] =
  ## Calls `ecdsa_public_key` of the Management Canister (ic0) and returns the result as a Future.
  result = newFuture[EcdsaPublicKeyResult]("publicKey")

  let mgmtPrincipalBytes: seq[uint8] = @[]
  let destPtr   = if mgmtPrincipalBytes.len > 0: mgmtPrincipalBytes[0].addr else: nil
  let destLen   = mgmtPrincipalBytes.len

  let methodName = "ecdsa_public_key".cstring
  ic0_call_new(
    callee_src = cast[int](destPtr),
    callee_size = destLen,
    name_src = cast[int](methodName),
    name_size = methodName.len,
    reply_fun = cast[int](onCallPublicKeyCanister),
    reply_env = cast[int](result),
    reject_fun = cast[int](onCallPublicKeyReject),
    reject_env = cast[int](result)
  )

  ## 3. Attach argument data and execute
  try:
    let candidValue = newCandidRecord(arg)
    let encoded = encodeCandidMessage(@[candidValue])
    ic0_call_data_append(ptrToInt(addr encoded[0]), encoded.len)
    let err = ic0_call_perform()
    if err != 0:
      let msg = "call_perform failed with error: " & $err
      fail(result, newException(ValueError, msg))
      return
  except Exception as e:
    fail(result, e)
    return


proc sign*(_:type ManagementCanister, arg: EcdsaSignArgs): Future[SignWithEcdsaResult] =
  ## Calls `sign_with_ecdsa` of the Management Canister (ic0) and returns the result as a Future.
  result = newFuture[SignWithEcdsaResult]("sign")

  let mgmtPrincipalBytes: seq[uint8] = @[]
  let destPtr   = if mgmtPrincipalBytes.len > 0: mgmtPrincipalBytes[0].addr else: nil
  let destLen   = mgmtPrincipalBytes.len

  let methodName = "sign_with_ecdsa".cstring
  ic0_call_new(
    callee_src = cast[int](destPtr),
    callee_size = destLen,
    name_src = cast[int](methodName),
    name_size = methodName.len,
    reply_fun = cast[int](onCallSignCanister),
    reply_env = cast[int](result),
    reject_fun = cast[int](onCallSignReject),
    reject_env = cast[int](result)
  )

  ## 3. Attach argument data and execute
  try:
    let candidValue = newCandidRecord(arg)
    let encoded = encodeCandidMessage(@[candidValue])
    ic0_call_data_append(ptrToInt(addr encoded[0]), encoded.len)
    let err = ic0_call_perform()
    if err != 0:
      let msg = "call_perform failed with error: " & $err
      fail(result, newException(ValueError, msg))
      return
  except Exception as e:
    fail(result, e)
    return
