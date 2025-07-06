import std/asyncdispatch
import std/options
import std/sequtils
import std/strutils
import std/tables
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/canisters/management_canister
import ../../../../src/nicp_cdk/ic_types/candid_types
import ../../../../src/nicp_cdk/ic_types/ic_record
import ../../../../src/nicp_cdk/algorithm/eth_address
import ./ecdsa

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
    let publicKey = icpPublicKeyToEvmAddress(publicKeyBytes)
    reply(publicKey)
  except ValueError as e:
    reject("Failed to get public key: " & e.msg)


proc getPublicKey*() =
  let caller = Msg.caller()
  if keys.hasKey(caller):
    let publicKeyBytes = keys[caller]
    let publicKey = icpPublicKeyToEvmAddress(publicKeyBytes)
    reply(publicKey)
  else:
    reject("No key found")


proc signMessage*() {.async.} =
  echo "=== signMessage"
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
  let signature = "0x" & signatureResult.signature.mapIt(it.toHex(2)).join("").toLowerAscii()
  reply(signature)


proc verify*() {.async.} =
  let request = Request.new() 
  let message = request.getStr(0)
  let messageHash = keccak256Hash(message)

  let caller = Msg.caller()
  let publicKeyBytes = keys[caller]
  echo "publicKeyBytes: ", publicKeyBytes
  echo "publicKey.len: ", publicKeyBytes.len

  let signature = request.getStr(1)
  let result = verifyEcdsaSignature(publicKeyBytes, messageHash, signature)
  reply(result)
