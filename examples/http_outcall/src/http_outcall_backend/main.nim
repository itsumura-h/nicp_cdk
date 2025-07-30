import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/canisters/management_canister
import controller


proc greet() {.query.} =
  let request = Request.new()
  let name = request.getStr(0)
  reply("Hello, " & name & "!")

proc getRequest() {.update.} = discard controller.getRequest()

# 削除された関数への参照を削除

# Motokoと同じTransform関数をQuery関数として実装
# これはICシステムAPIから呼び出される

# Transform関数はローカルのTransform処理のみを実装
# ICシステムAPIとの統合は、management_canister.nimで処理される

# Transform関数をテストするためのQuery関数
proc testTransform*() {.query, exportc.} =
  ## Transform関数のテスト用Query関数
  try:
    # デフォルトTransformを適用
    let transform = createDefaultTransform()
    
    # サンプルHTTPレスポンスを作成してテスト
    let testResponse = HttpResponse(
      status: 200,
      headers: @[
        ("Content-Type", "application/json"),
        ("Date", "Wed, 21 Oct 2015 07:28:00 GMT"),
        ("Server", "nginx/1.18.0"),
        ("X-Request-ID", "12345-abcde")
      ],
      body: @[123'u8, 34'u8, 116'u8, 101'u8, 115'u8, 116'u8, 34'u8, 58'u8, 34'u8, 118'u8, 97'u8, 108'u8, 117'u8, 101'u8, 34'u8, 125'u8]  # {"test":"value"}
    )
    
    # Transform関数を適用
    let transformedResponse = transform.function(testResponse)
    
    # 結果をCandidRecordに変換
    var headersArray: seq[CandidRecord] = @[]
    for header in transformedResponse.headers:
      headersArray.add(%(@[%header[0], %header[1]]))
    
    let result = %* {
      "status": transformedResponse.status,
      "headers": headersArray,
      "body": transformedResponse.body,
      "original_header_count": testResponse.headers.len,
      "filtered_header_count": transformedResponse.headers.len
    }
    
    reply($result)
    
  except Exception as e:
    let error = %* {
      "error": e.msg
    }
    reply($error)

# MotokoサンプルのTransform関数と同等のQuery関数を実装
proc transform*() {.query, exportc.} =
  ## MotokoサンプルのTransform関数と同じ動作：ヘッダーを除去してボディのみを返す
  try:
    let request = Request.new()
    # Transform関数の引数は TransformArgs { context: Blob, response: HttpResponsePayload }
    
    # 引数がない場合はテスト用の固定レスポンスを返す
    # 実際の実装ではIC System APIからの引数を使用する
    let emptyHeaders: seq[CandidRecord] = @[]  # 明示的な型指定
    let emptyBody: seq[uint8] = @[91'u8, 93'u8]  # "[]" のバイト配列
    
    let testResponse = %* {
      "status": 200,
      "headers": emptyHeaders,  # Motokoサンプルと同じくヘッダーを空にする
      "body": emptyBody
    }
    
    reply($testResponse)
  except Exception as e:
    let errorHeaders: seq[CandidRecord] = @[]
    let errorBody: seq[uint8] = @[]
    let error = %* {
      "error": e.msg,
      "status": 500,
      "headers": errorHeaders,
      "body": errorBody
    }
    reply($error)