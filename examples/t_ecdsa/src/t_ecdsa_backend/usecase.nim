import std/asyncdispatch
import std/tables
import std/options
import std/sequtils
import std/strutils
import std/strformat
import secp256k1
import ../../../../src/nicp_cdk/canisters/management_canister
import ../../../../src/nicp_cdk/ic_types/candid_types
import ../../../../src/nicp_cdk/ic_types/ic_record
import ../../../../src/nicp_cdk/algorithm/ethereum
import ../../../../src/nicp_cdk/algorithm/ecdsa
import ../../../../src/nicp_cdk/ic_types/ic_principal
import ./database


proc getNewPublicKey*(caller: Principal): Future[string] {.async.} =
  if database.hasKey(caller):
    return toHexString(database.getPublicKey(caller))

  let arg = EcdsaPublicKeyArgs(
    canister_id: Principal.fromText("lz3um-vp777-77777-aaaba-cai").some(),
    derivation_path: @[caller.bytes],
    key_id: EcdsaKeyId(
      curve: EcdsaCurve.secp256k1,
      name: "dfx_test_key"
    )
  )
  
  let publicKeyResult = await ManagementCanister.publicKey(arg)
  let publicKeyBytes = publicKeyResult.public_key
  database.setPublicKey(caller, publicKeyBytes)
  let publicKey = toHexString(publicKeyBytes)
  return publicKey


proc getPublicKey*(caller: Principal): string =
  if database.hasKey(caller):
    let publicKeyBytes = database.getPublicKey(caller)
    return toHexString(publicKeyBytes)
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
  
  # secp256k1ライブラリを使用した署名検証
  let sigResult = SkSignature.fromHex(signResult.signature.toHexString())
  let msgResult = SkMessage.fromBytes(messageHash)
  let pubKeyResult = SkPublicKey.fromRaw(hexToBytes(getPublicKey(caller)))
  
  # 全ての結果が正常かチェック
  if sigResult.isErr or msgResult.isErr or pubKeyResult.isErr:
    echo "Error parsing signature components:"
    if sigResult.isErr:
      echo "  Signature error: ", sigResult.error
    if msgResult.isErr:
      echo "  Message error: ", msgResult.error
    if pubKeyResult.isErr:
      echo "  Public key error: ", pubKeyResult.error
    return ""
  
  # 署名検証を実行
  let isValid = secp256k1.verify(
    sigResult.get(),
    msgResult.get(),
    pubKeyResult.get()
  )
  echo "isValid: ", isValid

  if isValid:
    return toHexString(signResult.signature)
  else:
    return ""


proc verifyWithEcdsa*(message: string, signature: string, publicKey: string): bool =
  let messageHash = ecdsa.keccak256Hash(message)

  let sigResult = SkSignature.fromHex(signature)
  let msgResult = SkMessage.fromBytes(messageHash)
  let pubKeyResult = SkPublicKey.fromRaw(hexToBytes(publicKey))

  if sigResult.isErr or msgResult.isErr or pubKeyResult.isErr:
    raise newException(Exception, "Failed to verify with ECDSA")

  return secp256k1.verify(
    sigResult.get(),
    msgResult.get(),
    pubKeyResult.get()
  )
