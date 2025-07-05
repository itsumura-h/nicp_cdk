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


var keys = initTable[Principal, string]()

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
    let publicKey = icpPublicKeyToEvmAddress(publicKeyBytes)
    echo "publicKey: ", publicKey
    keys[caller] = publicKey
    reply(publicKey)
  except ValueError as e:
    reject("Failed to get public key: " & e.msg)


proc getPublicKey*() =
  let caller = Msg.caller()
  if keys.hasKey(caller):
    reply(keys[caller])
  else:
    reject("No key found")


proc signMessage*() {.async.} =
  let caller = Msg.caller()
  let request = Request.new() 
  let message = request.getStr(0)

  let arg = EcdsaSignArgs(
    message_hash: message.mapIt(it.uint8),
    derivation_path: @[caller.bytes],
    key_id: EcdsaKeyId(
      curve: EcdsaCurve.secp256k1,
      name: "dfx_test_key"
    )
  )
  let signatureResult = await ManagementCanister.sign(arg)
  let signature = "0x" & signatureResult.signature.mapIt(it.toHex(2)).join("")
  reply(signature)
