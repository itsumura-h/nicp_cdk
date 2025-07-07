import std/asyncdispatch
import std/options
import std/sequtils
import std/strutils
import std/tables
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/canisters/management_canister
import ../../../../src/nicp_cdk/ic_types/candid_types
import ../../../../src/nicp_cdk/ic_types/ic_record
import ../../../../src/nicp_cdk/algorithm/ethereum
import ../../../../src/nicp_cdk/algorithm/ecdsa

var keys = initTable[Principal, seq[uint8]]()

proc getNewPublicKey*() {.async.} =
  let caller = Msg.caller()

  if keys.hasKey(caller):
    reply(keys[caller])
    return

  let arg = EcdsaPublicKeyArgs(
    canister_id: Principal.fromText("bd3sg-teaaa-aaaaa-qaaba-cai").some(),
    derivation_path: @[caller.bytes],
    key_id: EcdsaKeyId(
      curve: EcdsaCurve.secp256k1,
      name: "dfx_test_key"
    )
  )

  try:
    let publicKeyResult = await ManagementCanister.publicKey(arg)
    let publicKeyBytes = publicKeyResult.public_key
    keys[caller] = publicKeyBytes
    let publicKey = toHexString(publicKeyBytes)
    reply(publicKey)
  except ValueError as e:
    reject("Failed to get public key: " & e.msg)


proc getPublicKey*() =
  let caller = Msg.caller()
  if keys.hasKey(caller):
    let publicKeyBytes = keys[caller]
    let publicKey = toHexString(publicKeyBytes)
    reply(publicKey)
  else:
    reject("No key found")


proc signWithEcdsa*() {.async.} =
  echo "=== signWithEcdsa"
  let request = Request.new() 
  let message = request.getStr(0)
  echo "message: ", message
  let caller = Msg.caller()
  echo "caller: ", caller.text

  if not keys.hasKey(caller):
    reject("No public key generated")

  let messageHash = keccak256Hash(message)
  echo "messageHash: ", messageHash

  let arg = EcdsaSignArgs(
    message_hash: messageHash,
    derivation_path: @[caller.bytes],
    key_id: EcdsaKeyId(
      curve: EcdsaCurve.secp256k1,
      name: "dfx_test_key"
    )
  )
  echo "arg: ", arg
  let signatureResult = await ManagementCanister.sign(arg)
  let signature = signatureResult.signature.toHexString()
  reply(signature)


proc verifyWithEcdsa*() {.async.} =
  let request = Request.new() 
  let argRecord = request.getRecord(0)
  let message = argRecord["message"].getStr()
  echo "message: ", message
  let messageHash = keccak256Hash(message)
  echo "messageHash: ", messageHash
  let signature = argRecord["signature"].getStr()
  echo "signature: ", signature
  let signatureBytes = hexToBytes(signature)
  echo "signatureBytes: ", signatureBytes
  let publicKey = argRecord["publicKey"].getStr()
  echo "publicKey: ", publicKey
  let publicKeyBytes = hexToBytes(publicKey)
  let result = verifyEcdsaSignature(messageHash, signatureBytes, publicKeyBytes)
  reply(result)


proc getEvmAddress*() =
  let caller = Msg.caller()
  if keys.hasKey(caller):
    let publicKeyBytes = keys[caller]
    let evmAddress = icpPublicKeyToEvmAddress(publicKeyBytes)
    reply(evmAddress)
  else:
    reject("No public key generated")


proc signWithEvm*() {.async.} =
  let caller = Msg.caller()
  if not keys.hasKey(caller):
    reject("No public key generated")

  let request = Request.new()
  let message = request.getStr(0)

  let messageHash = keccak256Hash(message)
  let arg = EcdsaSignArgs(
    message_hash: messageHash,
    derivation_path: @[caller.bytes],
    key_id: EcdsaKeyId(
      curve: EcdsaCurve.secp256k1,
      name: "dfx_test_key"
    )
  )
  let signatureResult = await ManagementCanister.sign(arg)
  let signature = signatureResult.signature.toHexString()
  reply(signature)