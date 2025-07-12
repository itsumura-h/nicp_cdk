import std/asyncdispatch
import std/strutils
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/ic_types/candid_types
import ../../../../src/nicp_cdk/ic_types/ic_record
import ../../../../src/nicp_cdk/algorithm/ethereum
import ../../../../src/nicp_cdk/algorithm/ecdsa
import ./usecase


proc getNewPublicKey*() {.async.} =
  let caller = Msg.caller()

  try:
    let publicKey = await usecase.getNewPublicKey(caller)
    reply(publicKey)
  except ValueError as e:
    reject("Failed to get public key: " & e.msg)


proc getPublicKey*() =
  let caller = Msg.caller()
  try:
    let publicKey = usecase.getPublicKey(caller)
    reply(publicKey)
  except Exception as e:
    reject("Failed to get public key: " & e.msg)


proc signWithEcdsa*() {.async.} =
  let request = Request.new()
  let message = request.getStr(0)
  let caller = Msg.caller()

  discard await usecase.getNewPublicKey(caller)
  
  try:
    let signature = await usecase.signWithEcdsa(caller, message)
    reply(signature)
  except Exception as e:
    echo "Error in signWithEcdsa: ", e.msg
    reject("Failed to sign with ECDSA: " & e.msg)


proc verifyWithEcdsa*() =
  let request = Request.new()
  let argRecord = request.getRecord(0)
  let message = argRecord["message"].getStr()
  let signature = argRecord["signature"].getStr()
  let publicKey = argRecord["publicKey"].getStr()

  try:
    let isValid = usecase.verifyWithEcdsa(message, signature, publicKey)
    reply(isValid)
  except Exception as e:
    echo "Error in verifyWithEcdsa: ", e.msg
    reject("Failed to verify with ECDSA: " & e.msg)


proc getEvmAddress*() =
  let caller = Msg.caller()
  let publicKeyBytes = usecase.getPublicKey(caller)
  if publicKeyBytes.len > 0:
    let evmAddress = icpPublicKeyToEvmAddress(hexToBytes(publicKeyBytes))
    reply(evmAddress)
  else:
    reject("No public key generated")


# proc signWithEvm*() {.async.} =
#   echo "=== signWithEvm"
#   let caller = Msg.caller()
#   echo "caller: ", caller.text
#   if not keys.hasKey(caller):
#     echo "No public key generated for caller"
#     reject("No public key generated")
#     return

#   let request = Request.new()
#   let message = request.getStr(0)
#   echo "message: ", message
#   let messageHash = ethereum.keccak256Hash(message)
#   echo "messageHash: ", messageHash
#   let arg = EcdsaSignArgs(
#     message_hash: messageHash,
#     derivation_path: @[caller.bytes],
#     key_id: EcdsaKeyId(
#       curve: EcdsaCurve.secp256k1,
#       name: "dfx_test_key"
#     )
#   )
#   echo "arg: ", arg
  
#   try:
#     echo "Calling ManagementCanister.sign..."
#     let signatureResult = await ManagementCanister.sign(arg)
#     echo "signatureResult: ", signatureResult
#     let signature = signatureResult.signature.toEvmHexString()
#     echo "signature: ", signature
#     reply(signature)
#   except Exception as e:
#     echo "Exception in signWithEvm: ", e.msg
#     echo "Exception type: ", $type(e)
#     reject("Failed to sign with EVM: " & e.msg)


# proc verifyEvm*() =
#   let request = Request.new()
#   let argRecord = request.getRecord(0)
#   let message = argRecord["message"].getStr()
#   let signature = argRecord["signature"].getStr()
#   let evmAddress = argRecord["address"].getStr()
#   let result = verifyEthereumSignatureWithAddress(evmAddress, message, signature)
#   reply(result)


# proc testSecp256k1*() =
#   let result = ecdsa.testSecp256k1Operation()
#   reply(result)
