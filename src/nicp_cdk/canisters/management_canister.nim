import std/options
import std/asyncfutures
import std/asyncdispatch
import std/tables
import std/strutils
import std/sequtils
import ../ic0/ic0
import ../ic0/wasm
import ../ic_types/candid_types
import ../ic_types/ic_principal
import ../ic_types/ic_record
import ../ic_types/candid_message/candid_encode
import ../ic_types/candid_message/candid_decode
import ../ic_types/candid_message/candid_message_types

# Transform関数用の型定義を追加
type
  TransformArgs* = object
    response*: HttpResponsePayload
    context*: seq[uint8]  # Blob型（バイトシーケンス）

  HttpResponsePayload* = object
    status*: int
    headers*: seq[(string, string)]
    body*: seq[uint8]

# ================================================================================
# ECDSA related type definitions
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
  
  EcdsaPublicKeyResult* = object
    public_key*: seq[uint8]
    chain_code*: seq[uint8]

  EcdsaSignArgs* = object
    message_hash*: seq[uint8]
    derivation_path*: seq[seq[uint8]]
    key_id*: EcdsaKeyId

  SignWithEcdsaResult* = object
    signature*: seq[uint8]


# ================================================================================
# Conversion functions from CandidValue to ECDSA types
# ================================================================================
proc candidValueToEcdsaPublicKeyResult(candidValue: CandidValue): EcdsaPublicKeyResult =
  ## Converts a CandidValue to EcdsaPublicKeyResult
  if candidValue.kind != ctRecord:  
    raise newException(CandidDecodeError, "Expected record type for EcdsaPublicKeyResult")

  let recordVal = candidValueToCandidRecord(candidValue)
  let publicKeyVal = recordVal["public_key"].getBlob()
  let chainCodeVal = recordVal["chain_code"].getBlob()

  return EcdsaPublicKeyResult(
    public_key: publicKeyVal,
    chain_code: chainCodeVal
  )

proc candidValueToSignWithEcdsaResult(candidValue: CandidValue): SignWithEcdsaResult =
  ## Converts a CandidValue to SignWithEcdsaResult
  if candidValue.kind != ctRecord:  
    raise newException(CandidDecodeError, "Expected record type for SignWithEcdsaResult")

  let recordVal = candidValueToCandidRecord(candidValue)
  let signatureVal = recordVal["signature"].getBlob()

  return SignWithEcdsaResult(
    signature: signatureVal
  )


# ================================================================================
# Global callback functions
# ================================================================================
proc onCallPublicKeyCanister(env: uint32) {.exportc.} =
  ## Success callback: Restore Future from env and complete it
  let fut = cast[Future[EcdsaPublicKeyResult]](env)
  if fut == nil or fut.finished:
    return
  
  try:
    let size = ic0_msg_arg_data_size()
    var buf = newSeq[uint8](size)
    ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
    let decoded = decodeCandidMessage(buf)
    let publicKeyResult = candidValueToEcdsaPublicKeyResult(decoded.values[0])
    complete(fut, publicKeyResult)
  except Exception as e:
    fail(fut, e)


proc onCallSignCanister(env: uint32) {.exportc.} =
  ## Success callback: Restore Future from env and complete it
  let fut = cast[Future[SignWithEcdsaResult]](env)
  if fut == nil or fut.finished:
    return
  
  try:
    let size = ic0_msg_arg_data_size()
    var buf = newSeq[uint8](size)
    ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
    let decoded = decodeCandidMessage(buf)
    let signResult = candidValueToSignWithEcdsaResult(decoded.values[0])
    complete(fut, signResult)
  except Exception as e:
    fail(fut, e)


proc onCallPublicKeyReject(env: uint32) {.exportc.} =
  ## Failure callback for public key: Restore Future from env and fail it
  let fut = cast[Future[EcdsaPublicKeyResult]](env)
  if fut == nil or fut.finished:
    return
  # reject コールバック内では ic0_msg_arg_data_size は使用できない
  let msg = "ECDSA public key call was rejected by the management canister"
  fail(fut, newException(ValueError, msg))


proc onCallSignReject(env: uint32) {.exportc.} =
  ## Failure callback for sign: Restore Future from env and fail it
  let fut = cast[Future[SignWithEcdsaResult]](env)
  if fut == nil or fut.finished:
    return
  # reject コールバック内では ic0_msg_arg_data_size は使用できない
  let msg = "ECDSA sign call was rejected by the management canister"
  fail(fut, newException(ValueError, msg))


# ================================================================================
# Management Canister API
# ================================================================================
type ManagementCanister* = object

proc publicKey*(_:type ManagementCanister, arg: EcdsaPublicKeyArgs): Future[EcdsaPublicKeyResult] =
  ## Calls `ecdsa_public_key` of the Management Canister (ic0) and returns the result as a Future.
  result = newFuture[EcdsaPublicKeyResult]("publicKey")

  let mgmtPrincipalBytes: seq[uint8] = @[]
  let destPtr   = if mgmtPrincipalBytes.len > 0: mgmtPrincipalBytes[0].addr else: nil
  let destLen   = mgmtPrincipalBytes.len

  let methodName = "ecdsa_public_key".cstring
  ic0_call_new(
    callee_src = cast[int](destPtr),
    callee_size = destLen,
    name_src = cast[int](methodName),
    name_size = methodName.len,
    reply_fun = cast[int](onCallPublicKeyCanister),
    reply_env = cast[int](result),
    reject_fun = cast[int](onCallPublicKeyReject),
    reject_env = cast[int](result)
  )

  ## 3. Attach argument data and execute
  try:
    let candidValue = newCandidRecord(arg)
    let encoded = encodeCandidMessage(@[candidValue])
    ic0_call_data_append(ptrToInt(addr encoded[0]), encoded.len)
    let err = ic0_call_perform()
    if err != 0:
      let msg = "call_perform failed with error: " & $err
      fail(result, newException(ValueError, msg))
      return
  except Exception as e:
    fail(result, e)
    return


proc sign*(_:type ManagementCanister, arg: EcdsaSignArgs): Future[SignWithEcdsaResult] =
  ## Calls `sign_with_ecdsa` of the Management Canister (ic0) and returns the result as a Future.
  result = newFuture[SignWithEcdsaResult]("sign")

  let mgmtPrincipalBytes: seq[uint8] = @[]
  let destPtr   = if mgmtPrincipalBytes.len > 0: mgmtPrincipalBytes[0].addr else: nil
  let destLen   = mgmtPrincipalBytes.len

  let methodName = "sign_with_ecdsa".cstring
  ic0_call_new(
    callee_src = cast[int](destPtr),
    callee_size = destLen,
    name_src = cast[int](methodName),
    name_size = methodName.len,
    reply_fun = cast[int](onCallSignCanister),
    reply_env = cast[int](result),
    reject_fun = cast[int](onCallSignReject),
    reject_env = cast[int](result)
  )

  ## 3. Attach argument data and execute
  try:
    let candidValue = newCandidRecord(arg)
    let encoded = encodeCandidMessage(@[candidValue])
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
# HTTP Outcall related type definitions
# ================================================================================
type
  HttpMethod* {.pure.} = enum
    GET = "GET"
    POST = "POST"
    HEAD = "HEAD"
    PUT = "PUT"
    DELETE = "DELETE"
    PATCH = "PATCH"
    OPTIONS = "OPTIONS"

  HttpResponse* = object
    status*: uint64
    headers*: seq[(string, string)]
    body*: seq[uint8]

  HttpTransformFunction* = proc(response: HttpResponse): HttpResponse {.nimcall.}

  HttpTransform* = object
    function*: HttpTransformFunction
    context*: seq[uint8]

  HttpRequest* = object
    url*: string
    max_response_bytes*: Option[uint64]
    headers*: seq[(string, string)]
    body*: Option[seq[uint8]]
    httpMethod*: HttpMethod
    transform*: Option[HttpTransform]


# ================================================================================
# Transform Functions
# ================================================================================

proc createDefaultTransform*(): HttpTransform =
  ## デフォルトのTransform関数: ヘッダーからタイムスタンプを除去
  proc defaultTransform(response: HttpResponse): HttpResponse =
    var filteredHeaders: seq[(string, string)] = @[]
    for header in response.headers:
      # 一般的な可変ヘッダーを除去
      let headerNameLower = header[0].toLowerAscii()
      if headerNameLower notin [
        "date", "server", "x-request-id", "x-timestamp", 
        "set-cookie", "expires", "last-modified", "etag",
        "cache-control", "pragma", "vary", "age",
        "x-frame-options", "x-content-type-options",
        "strict-transport-security", "x-xss-protection"
      ]:
        filteredHeaders.add(header)
    
    HttpResponse(
      status: response.status,
      headers: filteredHeaders,
      body: response.body
    )
  
  HttpTransform(
    function: defaultTransform,
    context: @[]
  )

proc createJsonTransform*(): HttpTransform =
  ## JSON専用Transform関数: JSONフィールドから可変部分を除去
  proc jsonTransform(response: HttpResponse): HttpResponse =
    # まずデフォルトTransformを適用
    let defaultResult = createDefaultTransform().function(response)
    
    if defaultResult.status != 200:
      return defaultResult
    
    try:
      # レスポンスボディを文字列に変換
      var jsonStr = ""
      for b in defaultResult.body:
        jsonStr.add(char(b))
      
      # 簡易的なJSON正規化
      # 一般的な可変JSONフィールドを固定値に置換
      # 注意: 完全なJSON解析ではなく基本的な文字列置換
      
      # タイムスタンプフィールドを正規化
      jsonStr = jsonStr.replace("\"timestamp\":", "\"timestamp\":0,").replace(",0,", ":0,")
      
      # 日時フィールドを正規化
      if "\"time\":" in jsonStr:
        # 簡易的な日時フィールド置換
        var lines = jsonStr.split("\"time\":")
        if lines.len > 1:
          jsonStr = lines[0] & "\"time\":\"normalized\""
          if lines.len > 2:
            for i in 2..<lines.len:
              jsonStr.add("\"time\":\"normalized\"" & lines[i])
      
      # IDフィールドを正規化
      if "\"id\":" in jsonStr:
        # 簡易的なIDフィールド置換
        var lines = jsonStr.split("\"id\":")
        if lines.len > 1:
          jsonStr = lines[0] & "\"id\":\"normalized\""
          if lines.len > 2:
            for i in 2..<lines.len:
              jsonStr.add("\"id\":\"normalized\"" & lines[i])
      
      # 正規化された文字列をバイトに変換
      var normalizedBytes: seq[uint8] = @[]
      for c in jsonStr:
        normalizedBytes.add(uint8(ord(c)))
      
      HttpResponse(
        status: defaultResult.status,
        headers: defaultResult.headers,
        body: normalizedBytes
      )
    except Exception:
      # JSON処理でエラーが発生した場合はデフォルトTransformの結果を返す
      defaultResult
  
  HttpTransform(
    function: jsonTransform,
    context: @[]
  )


# ================================================================================
# Conversion functions from CandidValue to HTTP Outcall types
# ================================================================================

proc `%`*(request: HttpRequest): CandidRecord =
  ## HttpRequestをCandidRecordに変換（IC Management Canister仕様準拠）
  # IC公式仕様：ヘッダーは {name: Text, value: Text} 形式のレコード
  var headersArray: seq[CandidRecord] = @[]
  for header in request.headers:
    headersArray.add(%* {
      "name": header[0],
      "value": header[1]
    })
  
  # IC仕様：メソッドはVariant型（小文字ラベル + 空のRecord）
  # Motokoサンプルでは #get, #post 等の値なしVariantとして実装されている
  var methodVariant: CandidRecord
  let emptyRecord = %* {}  # 空のRecord
  case request.httpMethod
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
  
  # Transform関数を使わない場合の最小構成
  # MotokoサンプルはTransform関数ありなので、一旦Transform関数なしでテスト
  if request.transform.isSome:
    # Transform関数ありのフル構成
    result = %* {
      "url": request.url,
      "max_response_bytes": request.max_response_bytes,
      "headers": headersArray,
      "body": request.body,
      "method": methodVariant,
      "transform": %* {
        "function": "transform",  # Query関数名（後で実装）
        "context": newSeq[uint8]()  # 空のByteコンテキスト
      },
      "is_replicated": some(false)
    }
  else:
    # Transform関数なしの最小構成
    result = %* {
      "url": request.url,
      "max_response_bytes": request.max_response_bytes,
      "headers": headersArray,  
      "body": request.body,
      "method": methodVariant,
      "transform": none(CandidRecord),  # null
      "is_replicated": some(false)
    }

proc candidValueToHttpResponse(candidValue: CandidValue): HttpResponse =
  ## Converts a CandidValue to HttpResponse
  if candidValue.kind != ctRecord:
    raise newException(CandidDecodeError, "Expected record type for HttpResponse")

  let recordVal = candidValueToCandidRecord(candidValue)
  let statusVal = recordVal["status"].getNat64()
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


proc estimateHttpOutcallCost(request: HttpRequest): uint64 =
  ## HTTP Outcallのサイクル使用量を正確に計算（IC System API使用）
  
  # リクエストサイズを計算
  var requestSize = request.url.len.uint64
  
  # ヘッダーサイズ
  for header in request.headers:
    requestSize += header[0].len.uint64 + header[1].len.uint64
  
  # ボディサイズ
  if request.body.isSome:
    requestSize += request.body.get.len.uint64
  
  # HTTPメソッド名のサイズ
  requestSize += ($request.httpMethod).len.uint64
  
  # Transform関数サイズ（概算）
  if request.transform.isSome:
    requestSize += 100  # Transform関数の概算サイズ
  
  let maxResponseSize = request.max_response_bytes.get(2000000'u64)
  
  # IC System APIを使用して正確なコスト計算
  var costBuffer: array[16, uint8]  # 128bit for cycles
  ic0_cost_http_request(requestSize, maxResponseSize, ptrToInt(addr costBuffer[0]))
  
  # 128bitのコスト値をuint64に変換（下位64bitを使用）
  var exactCost: uint64 = 0
  for i in 0..<8:
    exactCost = exactCost or (uint64(costBuffer[i]) shl (i * 8))
  
  # 20%の安全マージンを追加
  return exactCost + (exactCost div 5)


proc transform*() {.async, query.} =
  ## Transform関数 - Motokoサンプルと同等の実装
  ## public query func transform(args : TransformArgs) : async HttpResponsePayload
  ## IC Management CanisterのTransform関数として動作
  
  # Motokoサンプルと同じ処理：ヘッダーを空にしてボディとステータスのみ返す
  # 実際の引数解析は後で実装、今はテスト用の固定レスポンス
  
  let emptyHeaders: seq[CandidRecord] = @[]  # 明示的な型指定
  let testBody: seq[uint8] = @[91'u8, 93'u8]  # "[]" のバイト配列
  
  let transformedResponse = %* {
    "status": 200,  # 固定ステータス（後で引数から取得）
    "headers": emptyHeaders,  # 空のヘッダー配列（Motokoと同じ）
    "body": testBody
  }
  
  # IC0 System APIを使用してレスポンスを返す
  let candidValue = recordToCandidValue(transformedResponse)
  let responseBytes = encodeCandidMessage(@[candidValue])
  if responseBytes.len > 0:
    ic0_msg_reply_data_append(cast[int](responseBytes[0].addr), responseBytes.len)
  ic0_msg_reply()


proc httpRequest*(_:type ManagementCanister, request: HttpRequest): Future[HttpResponse] =
  ## HTTP Outcallをマネジメントキャニスター経由で実行（Rust方式: 自動サイクル送信）
  result = newFuture[HttpResponse]("httpRequest")

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

  # Motokoと同じ固定サイクル数でテスト
  let totalCycles = 230_949_972_000'u64  # Motokoと同じサイクル数
  let cyclesHigh = 0'u64  # 上位64bit
  let cyclesLow = totalCycles  # 下位64bit
  
  echo "Adding cycles: ", totalCycles, " (", cyclesHigh, " high, ", cyclesLow, " low)"
  ic0_call_cycles_add128(cyclesHigh, cyclesLow)

  try:
    echo "Converting HttpRequest to CandidRecord..."
    let candidRecord = %request
    echo "CandidRecord: ", $candidRecord
    
    echo "Converting CandidRecord to CandidValue..."
    let candidValue = recordToCandidValue(candidRecord)
    
    echo "Encoding Candid message..."
    let encoded = encodeCandidMessage(@[candidValue])
    echo "Encoded message size: ", encoded.len, " bytes"
    
    # バイトレベルでのデバッグ出力（最初の64バイトまで）
    echo "Encoded bytes (hex, first 64 bytes):"
    var hexStr = ""
    for i in 0..<min(64, encoded.len):
      if i > 0 and i mod 16 == 0:
        hexStr.add("\n")
      elif i > 0 and i mod 8 == 0:
        hexStr.add("  ")
      elif i > 0:
        hexStr.add(" ")
      hexStr.add(encoded[i].toHex(2).toLowerAscii())
    echo hexStr
    
    ic0_call_data_append(ptrToInt(addr encoded[0]), encoded.len)
    
    echo "Performing HTTP Outcall..."
    let err = ic0_call_perform()
    if err != 0:
      let msg = "http_request call_perform failed with error: " & $err
      echo "❌ ", msg
      fail(result, newException(ValueError, msg))
      return
    else:
      echo "✅ HTTP Outcall initiated successfully"
  except Exception as e:
    echo "❌ HTTP Outcall preparation failed: ", e.msg
    echo "Exception details: ", e.name, " - ", e.getStackTrace()
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
    let contextValue = decoded.values[1]
    let contextRecord = candidValueToCandidRecord(contextValue)
    let transformName = contextRecord["function"].getStr()
    
    # 登録されたTransform関数を実行
    var transformedResponse = httpResponse
    
    if registeredTransforms.hasKey(transformName):
      transformedResponse = registeredTransforms[transformName](httpResponse)
    elif transformName == "default_transform":
      transformedResponse = createDefaultTransform().function(httpResponse)
    elif transformName == "json_transform":
      transformedResponse = createJsonTransform().function(httpResponse)
    else:
      # 未知のTransform関数の場合は元のレスポンスをそのまま返す
      transformedResponse = httpResponse
    
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
proc initHttpTransforms*() =
  ## HTTP Transform機能の初期化
  registerTransform("default_transform", createDefaultTransform().function)
  registerTransform("json_transform", createJsonTransform().function)


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

proc httpGet*(
  _: type ManagementCanister,
  url: string,
  headers: seq[(string, string)] = @[],
  maxResponseBytes: Option[uint64] = none(uint64),
  transform: Option[HttpTransform] = none(HttpTransform)
): Future[HttpResponse] =
  ## Convenient GET request
  let finalTransform = if transform.isSome: transform else: some(createDefaultTransform())
  let request = HttpRequest(
    url: url,
    httpMethod: HttpMethod.GET,
    headers: headers,
    body: none(seq[uint8]),
    max_response_bytes: maxResponseBytes,
    transform: finalTransform
  )
  return ManagementCanister.httpRequest(request)


proc httpPost*(
  _: type ManagementCanister,
  url: string,
  body: seq[uint8],
  headers: seq[(string, string)] = @[],
  maxResponseBytes: Option[uint64] = none(uint64),
  transform: Option[HttpTransform] = none(HttpTransform)
): Future[HttpResponse] =
  ## Convenient POST request
  let finalTransform = if transform.isSome: transform else: some(createDefaultTransform())
  let request = HttpRequest(
    url: url,
    httpMethod: HttpMethod.POST,
    headers: headers,
    body: some(body),
    max_response_bytes: maxResponseBytes,
    transform: finalTransform
  )
  return ManagementCanister.httpRequest(request)


proc httpPost*(
  _: type ManagementCanister,
  url: string,
  jsonBody: string,
  headers: seq[(string, string)] = @[],
  maxResponseBytes: Option[uint64] = none(uint64),
  transform: Option[HttpTransform] = none(HttpTransform)
): Future[HttpResponse] =
  ## Convenient POST request with JSON body
  var requestHeaders = headers
  requestHeaders.add(("Content-Type", "application/json"))
  var bodyBytes: seq[uint8] = @[]
  for c in jsonBody:
    bodyBytes.add(uint8(ord(c)))
  
  let finalTransform = if transform.isSome: transform else: some(createJsonTransform())
  return ManagementCanister.httpPost(url, bodyBytes, requestHeaders, maxResponseBytes, finalTransform)


proc httpPostJson*(
  _: type ManagementCanister,
  url: string,
  jsonBody: string,
  headers: seq[(string, string)] = @[],
  maxResponseBytes: Option[uint64] = none(uint64),
  idempotencyKey: Option[string] = none(string)
): Future[HttpResponse] =
  ## JSON POST request with Idempotency Key support
  var requestHeaders = headers
  requestHeaders.add(("Content-Type", "application/json"))
  
  # Idempotency Key の設定
  if idempotencyKey.isSome:
    requestHeaders.add(("Idempotency-Key", idempotencyKey.get))
  # TODO: UUIDライブラリが利用可能になったら自動生成を実装
  
  var bodyBytes: seq[uint8] = @[]
  for c in jsonBody:
    bodyBytes.add(uint8(ord(c)))
  
  return ManagementCanister.httpPost(url, bodyBytes, requestHeaders, maxResponseBytes, some(createJsonTransform()))


proc httpPut*(
  _: type ManagementCanister,
  url: string,
  body: seq[uint8],
  headers: seq[(string, string)] = @[],
  maxResponseBytes: Option[uint64] = none(uint64),
  transform: Option[HttpTransform] = none(HttpTransform)
): Future[HttpResponse] =
  ## Convenient PUT request
  let finalTransform = if transform.isSome: transform else: some(createDefaultTransform())
  let request = HttpRequest(
    url: url,
    httpMethod: HttpMethod.PUT,
    headers: headers,
    body: some(body),
    max_response_bytes: maxResponseBytes,
    transform: finalTransform
  )
  return ManagementCanister.httpRequest(request)


proc httpDelete*(
  _: type ManagementCanister,
  url: string,
  headers: seq[(string, string)] = @[],
  maxResponseBytes: Option[uint64] = none(uint64),
  transform: Option[HttpTransform] = none(HttpTransform)
): Future[HttpResponse] =
  ## Convenient DELETE request
  let finalTransform = if transform.isSome: transform else: some(createDefaultTransform())
  let request = HttpRequest(
    url: url,
    httpMethod: HttpMethod.DELETE,
    headers: headers,
    body: none(seq[uint8]),
    max_response_bytes: maxResponseBytes,
    transform: finalTransform
  )
  return ManagementCanister.httpRequest(request)
