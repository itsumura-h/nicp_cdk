import std/options
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/canisters/management_canister

proc getPublicKey() {.update.} =
  let arg = EcdsaPublicKeyArgs(
    canister_id: Principal.fromText("be2us-64aaa-aaaaa-qaabq-cai").some(),
    derivation_path: @[Msg.caller().bytes],
    key_id: EcdsaKeyId(
      curve: EcdsaCurve.secp256k1,
      name: "dfx_test_key"
    )
  )
  ManagementCanister.publicKey(arg)
  # reply("ecdsa public key fetched")
