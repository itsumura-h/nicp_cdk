import std/options
import std/asyncfutures
import std/tables
import ../ic_types/ic_principal
import ../ic_types/candid_types
import ../ic0/ic0
import ../ic_types/candid_message/candid_encode
import ../ic_types/candid_message/candid_decode
import ../ic_types/candid_message/candid_message_types
import ../ic_types/ic_record

# ================================================================================
# ECDSA 関連の型定義
# ================================================================================
type
  EcdsaCurve* {.pure.} = enum
    secp256k1 = 0
    secp256r1 = 1

  EcdsaKeyId* = object
    curve*: EcdsaCurve
    name*: string

  EcdsaPublicKeyArgs* = object
    canister_id*: Option[Principal]
    derivation_path*: seq[seq[uint8]]
    key_id*: EcdsaKeyId

  EcdsaSignArgs* = object
    message_hash*: seq[uint8]
    derivation_path*: seq[seq[uint8]]
    key_id*: EcdsaKeyId

  EcdsaPublicKeyResult* = object
    public_key*: seq[uint8]
    chain_code*: seq[uint8]

  SignWithEcdsaResult* = object
    signature*: seq[uint8]

# ----------------------------------------------------------------------------
# グローバルで進行中の Future を保持 (簡易実装)
# 同時に複数のリクエストを発行しない前提とする。
# ----------------------------------------------------------------------------
var gPendingPublicKey*: Future[EcdsaPublicKeyResult] = nil

# ================================================================================
# CandidValue から ECDSA 型への変換関数
# ================================================================================
proc candidValueToEcdsaPublicKeyResult*(candidValue: CandidValue): EcdsaPublicKeyResult =
  ## CandidValue から EcdsaPublicKeyResult に変換する
  if candidValue.kind != ctRecord:  
    raise newException(CandidDecodeError, "Expected record type for EcdsaPublicKeyResult")

  let recordVal = candidValueToCandidRecord(candidValue)
  let publicKeyVal = recordVal["public_key"].getBlob()
  let chainCodeVal = recordVal["chain_code"].getBlob()

  return EcdsaPublicKeyResult(
    public_key: publicKeyVal,
    chain_code: chainCodeVal
  )


# ================================================================================
# グローバルコールバック関数
# ================================================================================
proc onCallOuterCanister(env: uint32) {.exportc.} =
  ## 成功コールバック: 取得した公開鍵を Future に設定する
  echo "=== onCallOuterCanister start ==="
  let size = ic0_msg_arg_data_size()
  var buf = newSeq[uint8](size)
  ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
  let decoded = decodeCandidMessage(buf)
  let publicKeyResult = candidValueToEcdsaPublicKeyResult(decoded.values[0])
  if gPendingPublicKey != nil and not gPendingPublicKey.finished:
    complete(gPendingPublicKey, publicKeyResult)
  gPendingPublicKey = nil
  echo "=== onCallOuterCanister end ==="

proc onCallOuterCanisterReject(env: uint32) {.exportc.} =
  ## 失敗コールバック: Future を失敗で完了させる
  echo "=== onPublicKeyReject start ==="
  let err_size = ic0_msg_arg_data_size()
  var err_buf = newSeq[uint8](err_size)
  ic0_msg_arg_data_copy(ptrToInt(addr err_buf[0]), 0, err_size)
  let msg = "ECDSA publicKey call rejected: " & $err_buf
  if gPendingPublicKey != nil and not gPendingPublicKey.finished:
    fail(gPendingPublicKey, newException(ValueError, msg))
  gPendingPublicKey = nil
  echo "=== onPublicKeyReject end ==="


type ManagementCanister* = object

proc publicKey*(_:type ManagementCanister, arg: EcdsaPublicKeyArgs): Future[EcdsaPublicKeyResult] =
  ## 管理キャニスター (ic0) の `ecdsa_public_key` を呼び出し、結果を Future で返す。
  ## 複数同時呼び出しは未サポート（直近の呼び出しが優先）。

  echo "=== publicKey start ==="

  # 既に保留中の呼び出しがある場合はエラー
  if gPendingPublicKey != nil and not gPendingPublicKey.finished:
    let fut = newFuture[EcdsaPublicKeyResult]("publicKey")
    fail(fut, newException(ValueError, "Another publicKey call already in flight"))
    return fut

  result = newFuture[EcdsaPublicKeyResult]("publicKey")
  gPendingPublicKey = result

  let mgmtPrincipalBytes: seq[uint8] = @[]
  let destPtr   = if mgmtPrincipalBytes.len > 0: mgmtPrincipalBytes[0].addr else: nil
  let destLen   = mgmtPrincipalBytes.len

  let methodName = "ecdsa_public_key".cstring
  ic0_call_new(
    callee_src = cast[int](destPtr),
    callee_size = destLen,
    name_src = cast[int](methodName),
    name_size = methodName.len,
    reply_fun = cast[int](onCallOuterCanister),
    reply_env = 0,
    reject_fun = cast[int](onCallOuterCanisterReject),
    reject_env = 0
  )

  ## 3. 引数データを添付して実行
  let candidValue = newCandidRecord(arg)
  let encoded = encodeCandidMessage(@[candidValue])
  ic0_call_data_append(ptrToInt(addr encoded[0]), encoded.len)
  let err = ic0_call_perform()
  if err != 0:
    let msg = "call_perform failed"
    fail(result, newException(ValueError, msg))
    return

  echo "=== publicKey end ==="