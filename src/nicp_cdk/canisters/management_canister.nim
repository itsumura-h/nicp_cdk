import std/options
import std/asyncfutures
import std/tables
import ../ic0/ic0
import ../ic_types/candid_types
import ../ic_types/ic_principal
import ../ic_types/ic_record
import ../ic_types/candid_message/candid_encode
import ../ic_types/candid_message/candid_decode
import ../ic_types/candid_message/candid_message_types

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
# Conversion functions from CandidValue to HTTP Outcall types
# ================================================================================

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


proc httpRequest*(request: HttpRequest): Future[HttpResponse] =
  ## HTTP Outcallをマネジメントキャニスター経由で実行
  result = newFuture[HttpResponse]("httpRequest")

  let mgmtPrincipalBytes: seq[uint8] = @[]
  let destPtr = if mgmtPrincipalBytes.len > 0: mgmtPrincipalBytes[0].addr else: nil
  let destLen = mgmtPrincipalBytes.len

  let methodName = "http_request".cstring
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

  try:
    let candidValue = newCandidRecord(request)
    let encoded = encodeCandidMessage(@[candidValue])
    ic0_call_data_append(ptrToInt(addr encoded[0]), encoded.len)
    let err = ic0_call_perform()
    if err != 0:
      let msg = "http_request call_perform failed with error: " & $err
      fail(result, newException(ValueError, msg))
      return
  except Exception as e:
    fail(result, e)
    return


# ================================================================================
# Convenience HTTP methods
# ================================================================================

proc httpGet*(url: string, headers: seq[(string, string)] = @[], 
              maxResponseBytes: Option[uint64] = none(uint64)): Future[HttpResponse] =
  ## Convenient GET request
  let request = HttpRequest(
    url: url,
    httpMethod: HttpMethod.GET,
    headers: headers,
    body: none(seq[uint8]),
    max_response_bytes: maxResponseBytes,
    transform: none(HttpTransform)
  )
  return httpRequest(request)

proc httpPost*(url: string, body: seq[uint8], headers: seq[(string, string)] = @[],
               maxResponseBytes: Option[uint64] = none(uint64)): Future[HttpResponse] =
  ## Convenient POST request
  let request = HttpRequest(
    url: url,
    httpMethod: HttpMethod.POST,
    headers: headers,
    body: some(body),
    max_response_bytes: maxResponseBytes,
    transform: none(HttpTransform)
  )
  return httpRequest(request)

proc httpPost*(url: string, jsonBody: string, headers: seq[(string, string)] = @[],
               maxResponseBytes: Option[uint64] = none(uint64)): Future[HttpResponse] =
  ## Convenient POST request with JSON body
  var requestHeaders = headers
  requestHeaders.add(("Content-Type", "application/json"))
  var bodyBytes: seq[uint8] = @[]
  for c in jsonBody:
    bodyBytes.add(uint8(ord(c)))
  return httpPost(url, bodyBytes, requestHeaders, maxResponseBytes)

proc httpPut*(url: string, body: seq[uint8], headers: seq[(string, string)] = @[],
              maxResponseBytes: Option[uint64] = none(uint64)): Future[HttpResponse] =
  ## Convenient PUT request
  let request = HttpRequest(
    url: url,
    httpMethod: HttpMethod.PUT,
    headers: headers,
    body: some(body),
    max_response_bytes: maxResponseBytes,
    transform: none(HttpTransform)
  )
  return httpRequest(request)

proc httpDelete*(url: string, headers: seq[(string, string)] = @[],
                 maxResponseBytes: Option[uint64] = none(uint64)): Future[HttpResponse] =
  ## Convenient DELETE request
  let request = HttpRequest(
    url: url,
    httpMethod: HttpMethod.DELETE,
    headers: headers,
    body: none(seq[uint8]),
    max_response_bytes: maxResponseBytes,
    transform: none(HttpTransform)
  )
  return httpRequest(request)