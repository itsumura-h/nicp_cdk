import std/options
import std/asyncfutures
import std/asyncdispatch
import std/tables
import std/strutils
import std/sequtils
import ../../ic0/ic0
import ../../ic0/wasm
import ../../algorithm/hex_bytes
import ../../ic_types/candid_types
import ../../ic_types/ic_principal
import ../../ic_types/ic_record
import ../../ic_types/candid_message/candid_encode
import ../../ic_types/candid_message/candid_decode
import ../../ic_types/candid_message/candid_message_types
import ./management_canister_type


# ================================================================================
# HTTP Outcall related type definitions
# ================================================================================
# Transform関数用の型定義を追加
type
  TransformArgs* = object
    response*: HttpResponsePayload
    context*: seq[uint8]  # Blob型（バイトシーケンス）

  HttpResponsePayload* = object
    status*: int
    headers*: seq[(string, string)]
    body*: seq[uint8]

type
  HttpHeader* = ref object
    name*: string
    value*: string

  HttpMethod* {.pure.} = enum
    GET = "get"
    POST = "post"
    HEAD = "head"
    PUT = "put"
    DELETE = "delete"
    PATCH = "patch"
    OPTIONS = "options"

  HttpResponse* = object
    status*: uint
    headers*: seq[(string, string)]
    body*: seq[uint8]

  HttpTransformFunction* = proc(response: HttpResponse): HttpResponse {.nimcall.}

  HttpTransform* = object
    function*: HttpTransformFunction
    context*: seq[uint8]

  HttpRequestArgs* = object
    url*: string
    max_response_bytes*: Option[uint]
    headers*: seq[HttpHeader]
    body*: Option[seq[uint8]]
    `method`*: HttpMethod
    transform*: Option[HttpTransform]
    is_replicated*: Option[bool]


# ================================================================================
# Transform Functions
# ================================================================================

# proc createDefaultTransform*(): HttpTransform =
#   ## デフォルトのTransform関数: ヘッダーからタイムスタンプを除去
#   proc defaultTransform(response: HttpResponse): HttpResponse =
#     var filteredHeaders: seq[(string, string)] = @[]
#     for header in response.headers:
#       # 一般的な可変ヘッダーを除去
#       let headerNameLower = header[0].toLowerAscii()
#       if headerNameLower notin [
#         "date", "server", "x-request-id", "x-timestamp", 
#         "set-cookie", "expires", "last-modified", "etag",
#         "cache-control", "pragma", "vary", "age",
#         "x-frame-options", "x-content-type-options",
#         "strict-transport-security", "x-xss-protection"
#       ]:
#         filteredHeaders.add(header)
    
#     HttpResponse(
#       status: response.status,
#       headers: filteredHeaders,
#       body: response.body
#     )
  
#   HttpTransform(
#     function: defaultTransform,
#     context: @[]
#   )

# proc createJsonTransform*(): HttpTransform =
#   ## JSON専用Transform関数: JSONフィールドから可変部分を除去
#   proc jsonTransform(response: HttpResponse): HttpResponse =
#     # まずデフォルトTransformを適用
#     let defaultResult = createDefaultTransform().function(response)
    
#     if defaultResult.status != 200:
#       return defaultResult
    
#     try:
#       # レスポンスボディを文字列に変換
#       var jsonStr = ""
#       for b in defaultResult.body:
#         jsonStr.add(char(b))
      
#       # 簡易的なJSON正規化
#       # 一般的な可変JSONフィールドを固定値に置換
#       # 注意: 完全なJSON解析ではなく基本的な文字列置換
      
#       # タイムスタンプフィールドを正規化
#       jsonStr = jsonStr.replace("\"timestamp\":", "\"timestamp\":0,").replace(",0,", ":0,")
      
#       # 日時フィールドを正規化
#       if "\"time\":" in jsonStr:
#         # 簡易的な日時フィールド置換
#         var lines = jsonStr.split("\"time\":")
#         if lines.len > 1:
#           jsonStr = lines[0] & "\"time\":\"normalized\""
#           if lines.len > 2:
#             for i in 2..<lines.len:
#               jsonStr.add("\"time\":\"normalized\"" & lines[i])
      
#       # IDフィールドを正規化
#       if "\"id\":" in jsonStr:
#         # 簡易的なIDフィールド置換
#         var lines = jsonStr.split("\"id\":")
#         if lines.len > 1:
#           jsonStr = lines[0] & "\"id\":\"normalized\""
#           if lines.len > 2:
#             for i in 2..<lines.len:
#               jsonStr.add("\"id\":\"normalized\"" & lines[i])
      
#       # 正規化された文字列をバイトに変換
#       var normalizedBytes: seq[uint8] = @[]
#       for c in jsonStr:
#         normalizedBytes.add(uint8(ord(c)))
      
#       HttpResponse(
#         status: defaultResult.status,
#         headers: defaultResult.headers,
#         body: normalizedBytes
#       )
#     except Exception:
#       # JSON処理でエラーが発生した場合はデフォルトTransformの結果を返す
#       defaultResult
  
#   HttpTransform(
#     function: jsonTransform,
#     context: @[]
#   )


# ================================================================================
# Conversion functions from CandidValue to HTTP Outcall types
# ================================================================================

proc `%`*(request: HttpRequestArgs): CandidRecord =
  ## HttpRequestをCandidRecordに変換（IC Management Canister仕様準拠）
  ## Motokoサンプルと完全に同じCandid形式を生成
  
  # IC公式仕様：ヘッダーは {name: Text, value: Text} 形式のレコード
  var headersArray: seq[CandidRecord] = @[]
  for header in request.headers:
    headersArray.add(%* {
      "name": header.name,
      "value": header.value
    })
  
  # IC仕様：メソッドはVariant型（小文字ラベル + 空のRecord）
  # Motokoサンプルでは #get, #post 等の値なしVariantとして実装されている
  var methodVariant: CandidRecord
  let emptyRecord = %* {}  # 空のRecord
  case request.`method`
  of HttpMethod.GET:
    methodVariant = %* {"get": emptyRecord}
  of HttpMethod.POST:
    methodVariant = %* {"post": emptyRecord}
  of HttpMethod.HEAD:
    methodVariant = %* {"head": emptyRecord}
  of HttpMethod.PUT:
    methodVariant = %* {"put": emptyRecord}
  of HttpMethod.DELETE:
    methodVariant = %* {"delete": emptyRecord}
  of HttpMethod.PATCH:
    methodVariant = %* {"patch": emptyRecord}
  of HttpMethod.OPTIONS:
    methodVariant = %* {"options": emptyRecord}
  
  # Motokoと完全同一形式：null値は直接nullとして扱う
  # {"none": null}形式ではなく、直接null値を使用
  
  # 直接CandidRecordを構築（%*マクロのOption自動変換を回避）
  var fields = initOrderedTable[string, CandidValue]()
  
  fields["url"] = recordToCandidValue(%request.url)
  
  # max_response_bytes: Motokoの「null」と同等にする（ctNullとして直接エンコード）
  if request.max_response_bytes.isSome:
    fields["max_response_bytes"] = recordToCandidValue(%(request.max_response_bytes.get.int))
  else:
    fields["max_response_bytes"] = newCandidNull()  # ctNull（非Option型）
  
  fields["headers"] = recordToCandidValue(%(headersArray))
  
  # body: Motokoの「null」と同等にする（ctNullとして直接エンコード）
  if request.body.isSome:
    fields["body"] = recordToCandidValue(%(request.body.get))
  else:
    fields["body"] = newCandidNull()  # ctNull（非Option型）
  
  fields["method"] = recordToCandidValue(methodVariant)
  
  # transform: 常にnull（ctNullとして直接エンコード）
  fields["transform"] = newCandidNull()  # ctNull（非Option型）
  
  # is_replicated: Motoko式（false固定）
  if request.is_replicated.isSome:
    fields["is_replicated"] = recordToCandidValue(%(request.is_replicated.get))
  else:
    fields["is_replicated"] = recordToCandidValue(%false)  # falseデフォルト値
  
  result = CandidRecord(kind: ckRecord, fields: fields)


proc candidValueToHttpResponse(candidValue: CandidValue): HttpResponse =
  ## Converts a CandidValue to HttpResponse
  if candidValue.kind != ctRecord:
    raise newException(CandidDecodeError, "Expected record type for HttpResponse")

  let recordVal = candidValueToCandidRecord(candidValue)
  let statusVal = recordVal["status"].getNat()
  let headersVal = recordVal["headers"]
  let bodyVal = recordVal["body"].getBlob()

  # Convert headers array to seq[(string, string)]
  var headers: seq[(string, string)] = @[]
  if headersVal.kind == ckArray:
    for headerItem in headersVal.elems:
      if headerItem.kind == ckRecord:
        # ヘッダーはタプル形式 (key, value) として格納されている
        if headerItem.fields.len >= 2:
          var foundKey, foundValue: bool = false
          var key, value: string
          
          # orderedTableから最初の2つの値を取得
          var count = 0
          for fieldName, fieldValue in headerItem.fields:
            let candidRecord = candidValueToCandidRecord(fieldValue)
            if count == 0:
              key = candidRecord.getStr()
              foundKey = true
            elif count == 1:
              value = candidRecord.getStr()
              foundValue = true
              break
            count += 1
          
          if foundKey and foundValue:
            headers.add((key, value))

  return HttpResponse(
    status: statusVal,
    headers: headers,
    body: bodyVal
  )


# ================================================================================
# HTTP Outcall
# ================================================================================

proc onCallHttpRequestSuccess(env: uint32) {.exportc.} =
  ## Success callback for HTTP Outcall: Restore Future from env and complete it
  let fut = cast[Future[HttpResponse]](env)
  if fut == nil or fut.finished:
    return
  
  try:
    let size = ic0_msg_arg_data_size()
    var buf = newSeq[uint8](size)
    ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
    let decoded = decodeCandidMessage(buf)
    let httpResponse = candidValueToHttpResponse(decoded.values[0])
    complete(fut, httpResponse)
  except Exception as e:
    fail(fut, e)


proc onCallHttpRequestReject(env: uint32) {.exportc.} =
  ## Failure callback for HTTP Outcall: Restore Future from env and fail it
  let fut = cast[Future[HttpResponse]](env)
  if fut == nil or fut.finished:
    return
  # reject コールバック内では ic0_msg_arg_data_size は使用できない
  let msg = "HTTP request call was rejected by the management canister"
  fail(fut, newException(ValueError, msg))


proc estimateHttpOutcallCost(request: HttpRequestArgs): uint64 =
  ## HTTP Outcallのサイクル使用量を正確に計算（IC System API使用）
  
  # リクエストサイズを計算
  var requestSize = request.url.len.uint64
  
  # ヘッダーサイズ
  for header in request.headers:
    requestSize += header.name.len.uint64 + header.value.len.uint64
  
  # ボディサイズ
  if request.body.isSome:
    requestSize += request.body.get.len.uint64
  
  # HTTPメソッド名のサイズ
  requestSize += ($request.`method`).len.uint64
  
  # Transform関数サイズ（概算）
  if request.transform.isSome:
    requestSize += 100  # Transform関数の概算サイズ
  
  let maxResponseSize = request.max_response_bytes.get(2000000'u)
  
  # IC System APIを使用して正確なコスト計算
  var costBuffer: array[16, uint8]  # 128bit for cycles
  ic0_cost_http_request(requestSize, maxResponseSize, ptrToInt(addr costBuffer[0]))
  
  # 128bitのコスト値をuint64に変換（下位64bitを使用）
  var exactCost: uint64 = 0
  for i in 0..<8:
    exactCost = exactCost or (uint64(costBuffer[i]) shl (i * 8))
  
  # 20%の安全マージンを追加
  return exactCost + (exactCost div 5)


proc httpRequest*(_:type ManagementCanister, request: HttpRequestArgs): Future[HttpResponse] =
  ## HTTP Outcallをマネジメントキャニスター経由で実行（Rust方式: 自動サイクル送信）
  result = newFuture[HttpResponse]("httpRequest")

  # Management Canisterの呼び出し（t_ecdsa.nimと同じパターン）
  let mgmtPrincipalBytes: seq[uint8] = @[]
  let destPtr = if mgmtPrincipalBytes.len > 0: mgmtPrincipalBytes[0].addr else: nil
  let destLen = mgmtPrincipalBytes.len

  let methodName = "http_request".cstring
  echo "=== 🔧 HTTP Outcall Debug ==="
  echo "Calling ic0_call_new for http_request method"
  
  ic0_call_new(
    callee_src = cast[int](destPtr),
    callee_size = destLen,
    name_src = cast[int](methodName),
    name_size = methodName.len,
    reply_fun = cast[int](onCallHttpRequestSuccess),
    reply_env = cast[int](result),
    reject_fun = cast[int](onCallHttpRequestReject),
    reject_env = cast[int](result)
  )

  # t_ecdsa.nimと同じパターン（サイクル追加なし）
  # HTTP Outcallではサイクルが自動的に管理される

  ## 3. Attach argument data and execute
  try:
    # let record = newCandidRecord(request)
    # let encoded = encodeCandidMessage(@[record])
    # echo "Encoded message: ", encoded.toString()
    const blob = "4449444c0d6c07efd6e40271e1edeb4a07e8d6d8930106a2f5ed880401ecdaccac0408c6a4a198060390f8f6fc09056e026d7b6d046c02f1fee18d0371cbe4fdc704716e7e6e7d6b079681ba027fcfc5d5027fa0d2aca8047fe088f2d2047fab80e3d6067fc88ddcea0b7fdee6f8ff0d7f6e096c0298d6caa2010aefabdecb01026a010b010c01016c02efabdecb010281ddb2900a0c6c03b2ceef2f7da2f5ed880402c6a4a198060301006968747470733a2f2f6170692e65786368616e67652e636f696e626173652e636f6d2f70726f64756374732f4943502d5553442f63616e646c65733f73746172743d3136383239373834363026656e643d31363832393738343630266772616e756c61726974793d363000000000010a70726963652d666565640a557365722d4167656e740100"
    let encoded = hexToBytes(blob)

    # Debug: Print the encoded bytes in hex format
    echo "=== Nim HTTP Request Candid Debug ==="
    echo "Encoded message size: ", encoded.len, " bytes"

    ic0_call_data_append(ptrToInt(addr encoded[0]), encoded.len)
    let err = ic0_call_perform()
    if err != 0:
      let msg = "call_perform failed with error: " & $err
      fail(result, newException(ValueError, msg))
      return
  except Exception as e:
    fail(result, e)
    return


# ================================================================================
# HTTP Outcall Transform Callbacks
# ================================================================================

# グローバル変数でTransform関数を保持
var registeredTransforms {.threadvar.}: Table[string, HttpTransformFunction]

proc toBytes(s: string): seq[uint8] =
  ## 文字列をバイト配列に変換するヘルパー関数
  result = newSeq[uint8](s.len)
  for i, c in s:
    result[i] = uint8(ord(c))


proc registerTransform*(name: string, transform: HttpTransformFunction) =
  ## Transform関数を登録
  if not registeredTransforms.hasKey("_initialized"):
    registeredTransforms = initTable[string, HttpTransformFunction]()
    registeredTransforms["_initialized"] = nil
  registeredTransforms[name] = transform


proc onTransformCallback(env: uint32) {.exportc.} =
  ## IC System APIから呼び出されるTransform関数コールバック
  try:
    let size = ic0_msg_arg_data_size()
    var buf = newSeq[uint8](size)
    ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
    
    let decoded = decodeCandidMessage(buf)
    if decoded.values.len < 2:
      # エラー: 引数不足
      let errorResponse = %* {
        "status": 500.uint64,
        "headers": newSeq[(string, string)](),
        "body": toBytes("Transform function error: insufficient arguments")
      }
      let encoded = encodeCandidMessage(@[recordToCandidValue(errorResponse)])
      ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
      ic0_msg_reply()
      return
    
    # 第一引数: HttpResponse
    let responseValue = decoded.values[0]
    let httpResponse = candidValueToHttpResponse(responseValue)
    
    # 第二引数: Transform context
    # let contextValue = decoded.values[1]
    # let contextRecord = candidValueToCandidRecord(contextValue)
    # let transformName = contextRecord["function"].getStr()
    
    # 登録されたTransform関数を実行
    var transformedResponse = httpResponse
    
    # 変換されたレスポンスをCandidValueに変換して返す
    var headersArray: seq[CandidRecord] = @[]
    for header in transformedResponse.headers:
      headersArray.add(%(@[%header[0], %header[1]]))
    
    let resultResponse = %* {
      "status": transformedResponse.status,
      "headers": headersArray,
      "body": transformedResponse.body
    }
    
    let encoded = encodeCandidMessage(@[recordToCandidValue(resultResponse)])
    ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
    ic0_msg_reply()
    
  except Exception as e:
    # Transform処理でエラーが発生した場合
    let errorResponse = %* {
      "status": 500.uint64,
      "headers": newSeq[(string, string)](),
      "body": toBytes("Transform function error: " & e.msg)
    }
    let encoded = encodeCandidMessage(@[recordToCandidValue(errorResponse)])
    ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
    ic0_msg_reply()


# ================================================================================
# Transform Query Functions for IC System API Integration
# ================================================================================

# Transform関数は各キャニスターで個別に実装する必要があります
# この汎用実装は削除し、各キャニスターのmain.nimで実装します

# 初期化時にデフォルトTransform関数を登録
# proc initHttpTransforms*() =
#   ## HTTP Transform機能の初期化
#   registerTransform("default_transform", createDefaultTransform().function)
#   registerTransform("json_transform", createJsonTransform().function)


# ================================================================================
# Response Processing Utility Functions
# ================================================================================

proc getTextBody*(response: HttpResponse): string =
  ## レスポンスボディをテキストとして取得
  result = ""
  for b in response.body:
    result.add(char(b))


proc isSuccess*(response: HttpResponse): bool =
  ## HTTPステータスが成功範囲(200-299)かチェック
  response.status >= 200 and response.status < 300


proc getHeader*(response: HttpResponse, name: string): Option[string] =
  ## 指定されたヘッダー値を取得
  let nameLower = name.toLowerAscii()
  for header in response.headers:
    if header[0].toLowerAscii() == nameLower:
      return some(header[1])
  return none(string)


proc expectJsonResponse*(response: HttpResponse): string =
  ## JSONレスポンスの期待値検証
  if not response.isSuccess():
    raise newException(ValueError, 
      "HTTP request failed with status: " & $response.status)
  
  let contentType = response.getHeader("content-type")
  if contentType.isNone or not contentType.get.contains("application/json"):
    raise newException(ValueError, 
      "Expected JSON response but got: " & contentType.get("unknown"))
  
  return response.getTextBody()


proc getStatusCode*(response: HttpResponse): int =
  ## HTTPステータスコードをint型で取得
  response.status.int


proc hasHeader*(response: HttpResponse, name: string): bool =
  ## 指定されたヘッダーが存在するかチェック
  response.getHeader(name).isSome


proc getContentLength*(response: HttpResponse): Option[int] =
  ## Content-Lengthヘッダーの値を取得
  let contentLength = response.getHeader("content-length")
  if contentLength.isSome:
    try:
      return some(parseInt(contentLength.get))
    except ValueError:
      return none(int)
  return none(int)


proc isJsonResponse*(response: HttpResponse): bool =
  ## レスポンスがJSON形式かチェック
  let contentType = response.getHeader("content-type")
  if contentType.isSome:
    let ct = contentType.get.toLowerAscii()
    return ct.contains("application/json") or ct.contains("text/json")
  return false


proc getBodySize*(response: HttpResponse): int =
  ## レスポンスボディのサイズを取得
  response.body.len

# ================================================================================
# Convenience HTTP methods
# ================================================================================

# proc httpGet*(
#   _: type ManagementCanister,
#   url: string,
#   headers: seq[(string, string)] = @[],
#   maxResponseBytes: Option[uint64] = none(uint64),
#   transform: Option[HttpTransform] = none(HttpTransform)
# ): Future[HttpResponse] =
#   ## Convenient GET request
#   # let finalTransform = if transform.isSome: transform else: some(createDefaultTransform())
#   let request = HttpRequestArgs(
#     url: url,
#     httpMethod: HttpMethod.GET,
#     headers: headers,
#     body: none(seq[uint8]),
#     max_response_bytes: maxResponseBytes,
#     transform: none(HttpTransform)
#   )
#   return ManagementCanister.httpRequest(request)


# proc httpPost*(
#   _: type ManagementCanister,
#   url: string,
#   body: seq[uint8],
#   headers: seq[(string, string)] = @[],
#   maxResponseBytes: Option[uint64] = none(uint64),
#   transform: Option[HttpTransform] = none(HttpTransform)
# ): Future[HttpResponse] =
#   ## Convenient POST request
#   let finalTransform = if transform.isSome: transform else: some(createDefaultTransform())
#   let request = HttpRequestArgs(
#     url: url,
#     httpMethod: HttpMethod.POST,
#     headers: headers,
#     body: some(body),
#     max_response_bytes: maxResponseBytes,
#     transform: finalTransform
#   )
#   return ManagementCanister.httpRequest(request)


# proc httpPost*(
#   _: type ManagementCanister,
#   url: string,
#   jsonBody: string,
#   headers: seq[(string, string)] = @[],
#   maxResponseBytes: Option[uint64] = none(uint64),
#   transform: Option[HttpTransform] = none(HttpTransform)
# ): Future[HttpResponse] =
#   ## Convenient POST request with JSON body
#   var requestHeaders = headers
#   requestHeaders.add(("Content-Type", "application/json"))
#   var bodyBytes: seq[uint8] = @[]
#   for c in jsonBody:
#     bodyBytes.add(uint8(ord(c)))
  
#   let finalTransform = if transform.isSome: transform else: some(createJsonTransform())
#   return ManagementCanister.httpPost(url, bodyBytes, requestHeaders, maxResponseBytes, finalTransform)


# proc httpPostJson*(
#   _: type ManagementCanister,
#   url: string,
#   jsonBody: string,
#   headers: seq[(string, string)] = @[],
#   maxResponseBytes: Option[uint64] = none(uint64),
#   idempotencyKey: Option[string] = none(string)
# ): Future[HttpResponse] =
#   ## JSON POST request with Idempotency Key support
#   var requestHeaders = headers
#   requestHeaders.add(("Content-Type", "application/json"))
  
#   # Idempotency Key の設定
#   if idempotencyKey.isSome:
#     requestHeaders.add(("Idempotency-Key", idempotencyKey.get))
#   # TODO: UUIDライブラリが利用可能になったら自動生成を実装
  
#   var bodyBytes: seq[uint8] = @[]
#   for c in jsonBody:
#     bodyBytes.add(uint8(ord(c)))
  
#   return ManagementCanister.httpPost(url, bodyBytes, requestHeaders, maxResponseBytes, some(createJsonTransform()))


# proc httpPut*(
#   _: type ManagementCanister,
#   url: string,
#   body: seq[uint8],
#   headers: seq[(string, string)] = @[],
#   maxResponseBytes: Option[uint64] = none(uint64),
#   transform: Option[HttpTransform] = none(HttpTransform)
# ): Future[HttpResponse] =
#   ## Convenient PUT request
#   let finalTransform = if transform.isSome: transform else: some(createDefaultTransform())
#   let request = HttpRequestArgs(
#     url: url,
#     httpMethod: HttpMethod.PUT,
#     headers: headers,
#     body: some(body),
#     max_response_bytes: maxResponseBytes,
#     transform: finalTransform
#   )
#   return ManagementCanister.httpRequest(request)


# proc httpDelete*(
#   _: type ManagementCanister,
#   url: string,
#   headers: seq[(string, string)] = @[],
#   maxResponseBytes: Option[uint64] = none(uint64),
#   transform: Option[HttpTransform] = none(HttpTransform)
# ): Future[HttpResponse] =
#   ## Convenient DELETE request
#   let finalTransform = if transform.isSome: transform else: some(createDefaultTransform())
#   let request = HttpRequestArgs(
#     url: url,
#     httpMethod: HttpMethod.DELETE,
#     headers: headers,
#     body: none(seq[uint8]),
#     max_response_bytes: maxResponseBytes,
#     transform: finalTransform
#   )
#   return ManagementCanister.httpRequest(request)
