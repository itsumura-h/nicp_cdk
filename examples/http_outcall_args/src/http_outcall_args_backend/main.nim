import std/options
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/ic_types/candid_types

type
  HttpHeader = ref object
    name: string
    value: string

  HttpMethod {.pure.} = enum
    get = 0
    post = 1
    put = 2
    delete = 3
    head = 4
    patch = 5
    options = 6

  HttpResponsePayload = ref object
    status: uint
    headers: seq[HttpHeader]
    body: seq[byte]

  TransformArgs = ref object
    context: seq[byte]
    response: HttpResponsePayload

  TransformFunc = proc(response: TransformArgs): HttpResponsePayload {.nimcall.}

  HttpRequestArgs = ref object
    url: string
    max_response_bytes: Option[uint]
    headers: seq[HttpHeader]
    body: Option[seq[byte]]
    transform: Option[TransformFunc]
    `method`: HttpMethod
    is_replicated: Option[bool]


proc httpRequestArgs() {.query.} =
  let ONE_MINUTE: uint64 = 60
  let start_timestamp: uint64 = 1682978460 # May 1, 2023 22:01:00 GMT
  let host: string = "api.exchange.coinbase.com"
  let url = "https://" & host & "/products/ICP-USD/candles?start=" & $start_timestamp & "&end=" & $start_timestamp & "&granularity=" & $ONE_MINUTE

  # 1.2 prepare headers for the system http_request call
  let requestHeaders = @[
    HttpHeader(name: "User-Agent", value: "price-feed")
  ]

  let httpRequest = HttpRequestArgs(
    url: url,
    max_response_bytes: none(uint), # optional for request
    headers: requestHeaders,
    body: none(seq[byte]), # optional for request
    `method`: HttpMethod.get,
    transform: none(TransformFunc),
    # Toggle this flag to switch between replicated and non-replicated http outcalls.
    is_replicated: some(false)
  )

  let httpRequestRecord = newCandidRecord(httpRequest)
  echo "httpRequestRecord: ", $httpRequestRecord

  reply(httpRequestRecord)
  