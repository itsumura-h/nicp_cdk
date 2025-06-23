import ../ic0/ic0
import ../ic_types/ic_principal
# import ../ic_types/management_canister/ic_ecdsa
import ../ic_types/candid_types
# import ./ic_async

# ecdsa_public_key の呼び出し結果を処理するコールバック
proc onPublicKeyReply(env: uint32) {.exportc.} =
  echo "=== onPublicKeyReply ==="
  let size = ic0_msg_arg_data_size()                       # 応答データのサイズ取得
  var buf = newSeq[uint8](size)                           
  # 応答データ（公開鍵とチェインコード）のコピー
  ic0_msg_arg_data_copy(cast[int](buf.addr), 0, size)
  # ※ここでbufには EcdsaPublicKeyResult のCandidエンコードが格納される
  # 必要に応じて buf から公開鍵bytesとチェインコードbytesをデコード
  # 例では単にそのまま呼び出し元に転送
  ic0_msg_reply_data_append(cast[int](buf.addr), size)                 # データを返信メッセージにセット
  ic0_msg_reply()                                          # 元の呼び出し元に返信を返す


# ecdsa_public_key の呼び出し結果を処理するコールバック
proc onPublicKeyReject(env: uint32) {.exportc.} =
  echo "=== onPublicKeyReject ==="
  let err_size = ic0_msg_arg_data_size()
  var err_buf = newSeq[uint8](err_size)
  ic0_msg_arg_data_copy(cast[int](err_buf.addr), 0, err_size)          # エラー内容の取得
  ic0_trap(cast[int](err_buf.addr), err_size)


proc fetchECDSAPublicKey*(arg: EcdsaPublicKeyArgs) =
  ## 1. 管理キャニスター "aaaaa-aa" の Principal（空のバイト列）を明示
  let mgmtPrincipalBytes: seq[uint8] = @[]         # "aaaaa-aa" のバイナリは空
  let destPtr   = if mgmtPrincipalBytes.len > 0: mgmtPrincipalBytes[0].addr else: nil
  let destLen   = mgmtPrincipalBytes.len    # 0
  let argBlob = serializeCandid(arg)
  echo "argBlob: ", argBlob
  echo "argBlob.toString(): ", argBlob.toString()
  echo "reply_fun: ", cast[int](onPublicKeyReply)
  echo "reject_fun: ", cast[int](onPublicKeyReject)

  ## 3. 管理キャニスター呼び出しの設定
  let methodName = "ecdsa_public_key".cstring
  ic0_call_new(
    callee_src = cast[int](destPtr),
    callee_size = destLen,
    name_src = cast[int](methodName),
    name_size = methodName.len-1,
    reply_fun = cast[int](onPublicKeyReply),
    reply_env = 0,
    reject_fun = cast[int](onPublicKeyReject),
    reject_env = 0
  )

  ## 4. 引数データを添付して実行
  let dataPtr = cast[int](argBlob.addr)  # ptr uint8 → int
  let dataLen = argBlob.len            # int
  ic0_call_data_append(dataPtr, dataLen)
  let err = ic0_call_perform()
  if err != 0:
    let msg = "call_perform failed"
    ic0_trap(cast[int](msg[0].addr), msg.len)

type ManagementCanister* = object

proc publicKey*(_:type ManagementCanister, arg: EcdsaPublicKeyArgs) =
  echo "=== management_canister.nim publicKey ==="
  # let payload = serializeCandid(arg)
  # echo "payload: ", payload
  # let res = call("ecdsa_public_key", payload)
  fetchECDSAPublicKey(arg)
  let n = ic0_msg_arg_data_size()
  var data = newSeq[byte](n)
  ic0_msg_arg_data_copy(cast[int](data[0].addr), 0, n)
  echo "data: ", data
  # echo "res: ", res