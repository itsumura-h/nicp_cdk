import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/management_canister/management_canitster


proc publicKey() {.update.} =
  let caller = Msg.caller()
  echo "caller: ", caller
  let arg = EcdsaPublicKeyArgs(
    canisterId: @[],
    derivationPath: caller.bytes,
    keyCurve: secp256k1,
    keyName: dfxTestKey
  )
  echo "arg: ", arg
  ManagementCanister.publicKey(arg)
  reply()
