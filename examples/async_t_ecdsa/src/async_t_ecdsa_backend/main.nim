import std/asyncdispatch
import std/options
import std/sequtils
import std/strutils
import std/tables
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/canisters/async_management_canister

proc getPublicKeyAsync() {.async.} =
  let caller = Msg.caller()
  let arg = EcdsaPublicKeyArgs(
    canister_id: Principal.fromText("be2us-64aaa-aaaaa-qaabq-cai").some(),
    derivation_path: @[caller.bytes],
    key_id: EcdsaKeyId(
      curve: EcdsaCurve.secp256k1,
      name: "dfx_test_key"
    )
  )

  try:
    let result = await ManagementCanister.publicKey(arg)
    let publicKey = "0x" & result.public_key.map(proc(x: uint8): string = x.toHex()).join("")
    reply(publicKey)
  except ValueError as e:
    reject("Failed to get public key: " & e.msg)

# ----------------------------------------------------------------------------
# IC に公開する update エントリポイント（返値なし）
# ----------------------------------------------------------------------------

proc getPublicKey*() {.update.} = discard getPublicKeyAsync()