import ../../../../src/nicp_cdk
# import ../../../../src/nicp_cdk/canisters/management_canister
import controller


proc greet() {.query.} =
  let request = Request.new()
  let name = request.getStr(0)
  reply("Hello, " & name & "!")

proc get_icp_usd_exchange() {.update.} = discard controller.get_icp_usd_exchange()



# MotokoサンプルのTransform関数と同等のQuery関数を実装
# proc transform*() {.query, exportc.} =
#   ## MotokoサンプルのTransform関数と同じ動作：ヘッダーを除去してボディのみを返す
#   try:
#     let request = Request.new()
#     # Transform関数の引数は TransformArgs { context: Blob, response: HttpResponsePayload }
    
#     # 引数がない場合はテスト用の固定レスポンスを返す
#     # 実際の実装ではIC System APIからの引数を使用する
#     let emptyHeaders: seq[CandidRecord] = @[]  # 明示的な型指定
#     let emptyBody: seq[uint8] = @[91'u8, 93'u8]  # "[]" のバイト配列
    
#     let testResponse = %* {
#       "status": 200,
#       "headers": emptyHeaders,  # Motokoサンプルと同じくヘッダーを空にする
#       "body": emptyBody
#     }
    
#     reply($testResponse)
#   except Exception as e:
#     let errorHeaders: seq[CandidRecord] = @[]
#     let errorBody: seq[uint8] = @[]
#     let error = %* {
#       "error": e.msg,
#       "status": 500,
#       "headers": errorHeaders,
#       "body": errorBody
#     }
#     reply($error)
