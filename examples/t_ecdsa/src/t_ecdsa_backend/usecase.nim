import std/asyncdispatch
import std/tables
import std/options
import std/sequtils
import std/strutils
import std/strformat
import ../../../../src/nicp_cdk/canisters/management_canister
import ../../../../src/nicp_cdk/ic_types/candid_types
import ../../../../src/nicp_cdk/ic_types/ic_record
import ../../../../src/nicp_cdk/algorithm/ethereum
import ../../../../src/nicp_cdk/algorithm/ecdsa
import ../../../../src/nicp_cdk/ic_types/ic_principal
import ./database


proc getNewPublicKey*(caller: Principal): Future[string] {.async.} =
  if database.hasKey(caller):
    return ecdsa.toHexString(database.getPublicKey(caller))

  let arg = EcdsaPublicKeyArgs(
    canister_id: none(Principal),
    derivation_path: @[caller.bytes],
    key_id: EcdsaKeyId(
      curve: EcdsaCurve.secp256k1,
      name: "dfx_test_key"
    )
  )
  
  let publicKeyResult = await ManagementCanister.publicKey(arg)
  let publicKeyBytes = publicKeyResult.public_key
  database.setPublicKey(caller, publicKeyBytes)
  let publicKey = ecdsa.toHexString(publicKeyBytes)
  return publicKey


proc getPublicKey*(caller: Principal): string =
  if database.hasKey(caller):
    let publicKeyBytes = database.getPublicKey(caller)
    return ecdsa.toHexString(publicKeyBytes)
  else:
    raise newException(Exception, "No public key generated for caller")


proc signWithEcdsa*(caller: Principal, message: string): Future[string] {.async.} =
  let messageHash = ecdsa.keccak256Hash(message)

  let arg = EcdsaSignArgs(
    message_hash: messageHash,
    derivation_path: @[caller.bytes],
    key_id: EcdsaKeyId(
      curve: EcdsaCurve.secp256k1,
      name: "dfx_test_key"
    )
  )

  let signResult = await ManagementCanister.sign(arg)
  
  # ecdsa.nimの関数を使用した署名検証
  let publicKeyBytes = ecdsa.hexToBytes(getPublicKey(caller))
  let isValid = ecdsa.validateSignatureWithSecp256k1(
    messageHash,
    signResult.signature,
    publicKeyBytes
  )

  if isValid:
    return ecdsa.toHexString(signResult.signature)
  else:
    return ""


proc verifyWithEcdsa*(message: string, signature: string, publicKey: string): bool =
  # ecdsa.nimの関数を使用した署名検証
  return ecdsa.verifySignatureWithSecp256k1(message, signature, publicKey)
