import std/asyncdispatch
import std/options
import std/sequtils
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/canisters/management_canister


proc get_icp_usd_exchange*() {.async.} =
  ## シンプルなHTTP Outcall実装 - Transform関数なしでデバッグ
  try:
    # Motokoと完全に同じ設定
    const ONE_MINUTE: uint64 = 60
    const START_TIMESTAMP: uint64 = 1682978460  # May 1, 2023 22:01:00 GMT
    const HOST = "api.exchange.coinbase.com"
    
    let url = "https://" & HOST & "/products/ICP-USD/candles?start=" & 
              $START_TIMESTAMP & "&end=" & $START_TIMESTAMP & 
              "&granularity=" & $ONE_MINUTE
    
    echo "=== 🚀 Nim HTTP Outcall Test (NO Transform) ==="
    echo "URL: ", url
    
    # Transform関数なしでテスト
    let request = HttpRequestArgs(
      url: url,
      httpMethod: HttpMethod.GET,
      headers: @[("User-Agent", "price-feed")],  # Motokoと同じヘッダー
      body: none(seq[uint8]),
      max_response_bytes: none(uint),  # Motokoと同じ（null指定）
      transform: none(HttpTransform),  # Transform関数なし
      is_replicated: some(false)
    )
    
    echo "Calling HTTP Outcall without Transform function..."
    echo "Request structure:"
    echo "  URL: ", request.url
    echo "  Method: ", request.httpMethod
    echo "  Headers: ", request.headers
    echo "  Body: ", if request.body.isSome: "present" else: "none"
    echo "  Max response bytes: ", if request.max_response_bytes.isSome: $request.max_response_bytes.get else: "none"
    echo "  Transform: ", if request.transform.isSome: "present" else: "NONE"
    echo "  Is replicated: ", if request.is_replicated.isSome: $request.is_replicated.get else: "none"
    
    let response = await ManagementCanister.httpRequest(request)
    
    echo "✅ Success! Status: ", response.status
    echo "Headers count: ", response.headers.len
    echo "Response size: ", response.body.len, " bytes"
    
    let body = response.getTextBody()
    echo "Response body: ", body
    
    reply(body)
    
  except Exception as e:
    echo "❌ HTTP Outcall Error: ", e.msg
    echo "Error type: ", e.name
    reject("HTTP Outcall failed: " & e.msg)
