import std/asyncdispatch
import std/options
import std/sequtils
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/canisters/management_canister


proc getRequest*() {.async.} =
  try:
    # 実際のHTTP Outcall実装でテスト（詳細ログ追加）
    echo "=== Starting HTTP Outcall Debug ==="
    echo "Target URL: http://localhost:8000"  
    echo "Headers: Content-Type: application/json"
    
    # リクエスト作成をデバッグ
    echo "Creating HTTP request object..."
    let request = HttpRequest(
      url: "http://localhost:8000",
      httpMethod: HttpMethod.GET,
      headers: @[("Content-Type", "application/json")],
      body: none(seq[uint8]),
      max_response_bytes: none(uint64),
      transform: none(HttpTransform)
    )
    echo "HTTP request object created successfully"
    
    # リクエストをCandidRecordに変換をデバッグ
    echo "Converting request to CandidRecord..."
    let candidRecord = %request
    echo "CandidRecord conversion successful"
    
    # Management Canister呼び出しをデバッグ
    echo "Calling Management Canister httpRequest..."
    let response = await ManagementCanister.httpRequest(request)
    echo "HTTP request completed successfully"
    echo "Response status: ", response.status
    echo "Response headers count: ", response.headers.len
    let body = response.getTextBody()
    echo "Response body length: ", body.len
    reply(body)
    
  except Exception as e:
    echo "=== ERROR OCCURRED ==="
    echo "Error type: ", $e.name
    echo "Error message: ", e.msg
    echo "Error trace: ", e.getStackTrace()
    reject("Failed to make HTTP request: " & e.msg)
