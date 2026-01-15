import std/asyncdispatch
import std/options
import std/sequtils
import std/strutils
import ../../../../../src/nicp_cdk
import ../../../../../src/nicp_cdk/canisters/management_canister


proc toBytes(value: string): seq[uint8] =
  result = newSeq[uint8](value.len)
  for i, c in value:
    result[i] = uint8(ord(c))

proc recordDesc(fields: seq[tuple[name: string, fieldType: CandidTypeDesc]]): CandidTypeDesc =
  CandidTypeDesc(kind: ctRecord, recordFields: fields)

proc vecDesc(element: CandidTypeDesc): CandidTypeDesc =
  CandidTypeDesc(kind: ctVec, vecElementType: element)

proc blobDesc(): CandidTypeDesc =
  CandidTypeDesc(kind: ctBlob)

proc textDesc(): CandidTypeDesc =
  CandidTypeDesc(kind: ctText)

proc nat16Desc(): CandidTypeDesc =
  CandidTypeDesc(kind: ctNat16)

proc httpHeaderDesc(): CandidTypeDesc =
  recordDesc(@[
    (name: "name", fieldType: textDesc()),
    (name: "value", fieldType: textDesc())
  ])

proc httpResponseDesc(): CandidTypeDesc =
  recordDesc(@[
    (name: "status", fieldType: nat16Desc()),
    (name: "headers", fieldType: vecDesc(httpHeaderDesc())),
    (name: "body", fieldType: blobDesc())
  ])

proc transformArgsDesc(): CandidTypeDesc =
  recordDesc(@[
    (name: "response", fieldType: httpResponseDesc()),
    (name: "context", fieldType: blobDesc())
  ])

proc defaultTransformRef(): HttpTransform =
  ## Transformはquery関数参照として渡す
  let selfPrincipal = Principal.fromText("lqy7q-dh777-77777-aaaaq-cai")
  let funcRef = IcFunc.new(selfPrincipal, FuncType.Query, "transform", @[ctRecord], some(ctRecord))
  funcRef.argsDesc = @[transformArgsDesc()]
  funcRef.returnsDesc = some(httpResponseDesc())
  HttpTransform(function: funcRef, context: @[])

proc transform*() =
  let request = Request.new()
  let args = request.getRecord(0)
  let status = args["response"]["status"].getNat16()
  let headers = args["response"]["headers"].getArray().map(
    proc(x: CandidRecord): HttpHeader =
      HttpHeader(name: x["name"].getStr(), value: x["value"].getStr())
  )
  let filteredHeaders = headers.filterIt(
    it.name.toLowerAscii() notin @[
      "date", "server", "x-request-id", "x-timestamp",
      "set-cookie", "etag", "last-modified", "expires",
      "cache-control", "pragma", "vary", "age"
    ]
  )
  let body = args["response"]["body"].getBlob()
  let response = HttpResponsePayload(status: status, headers: filteredHeaders, body: body)
  reply(response)


proc get_httpbin*() {.async.} =
  ## GETリクエストのサンプル
  try:
    let url = "https://httpbin.org/get"
    let request = HttpRequestArgs(
      url: url,
      httpMethod: HttpMethod.GET,
      headers: @[HttpHeader(name: "User-Agent", value: "nim-http-outcall")],
      body: none(seq[uint8]),
      max_response_bytes: none(uint),
      # transform: some(defaultTransformRef()),
      transform: none(HttpTransform),
      is_replicated: some(false)
    )

    let response = await ManagementCanister.httpRequest(request)
    reply(response.getTextBody())
  except Exception as e:
    reject("GET httpbin failed: " & e.msg)


proc post_httpbin*() {.async.} =
  ## POSTリクエストのサンプル
  try:
    let url = "https://httpbin.org/post"
    let body = toBytes("{\"message\":\"hello from nim\"}")
    let request = HttpRequestArgs(
      url: url,
      httpMethod: HttpMethod.POST,
      headers: @[
        HttpHeader(name: "Content-Type", value: "application/json"),
        HttpHeader(name: "User-Agent", value: "nim-http-outcall")
      ],
      body: some(body),
      max_response_bytes: none(uint),
      # transform: some(defaultTransformRef()),
      transform: none(HttpTransform),
      is_replicated: some(false)
    )

    let response = await ManagementCanister.httpRequest(request)
    reply(response.getTextBody())
  except Exception as e:
    reject("POST httpbin failed: " & e.msg)


proc get_transform_funcion*() =
  # let transform = defaultTransformRef()
  let selfPrincipal = Principal.fromText("lqy7q-dh777-77777-aaaaq-cai")
  let transformFunc = newCandidFunc(selfPrincipal, "transform")
  reply(transformFunc)
