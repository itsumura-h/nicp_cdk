import std/asyncdispatch
import std/options
import std/sequtils
import std/strutils
import std/tables
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/canisters/management_canister


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
    let result = await ManagementCanister.publicKey(arg)
    let publicKey = "0x" & result.public_key.map(proc(x: uint8): string = x.toHex()).join("")
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