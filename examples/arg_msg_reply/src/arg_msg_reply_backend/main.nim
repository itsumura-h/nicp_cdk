import std/strutils
import std/options
import std/tables
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/ic_types/candid_types
import ../../../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../../../src/nicp_cdk/ic_types/candid_funcs
import ../../../../src/nicp_cdk/ic0/ic0

# ================================================================================
# Phase 3: Enum型定義（Canister統合テスト用）
# ================================================================================

type
  SimpleStatus* {.pure.} = enum
    Active = 0
    Inactive = 1

  Priority* {.pure.} = enum
    Low = 0
    Medium = 1
    High = 2
    Critical = 3

  EcdsaCurve* {.pure.} = enum
    secp256k1 = 0
    secp256r1 = 1

# ================================================================================
# Phase 3.1: Enum引数・戻り値のCanister関数
# ================================================================================

proc argSimpleStatus*() {.query.} =
  echo "===== main.nim argSimpleStatus() ====="
  let request = Request.new()
  let arg = request.getEnum(0, SimpleStatus)
  icEcho "SimpleStatus arg: ", arg
  reply(arg)

proc responseSimpleStatus*() {.query.} =
  echo "===== main.nim responseSimpleStatus() ====="
  let status = SimpleStatus.Active
  icEcho "SimpleStatus response: ", status
  reply(status)

proc argPriority*() {.query.} =
  echo "===== main.nim argPriority() ====="
  let request = Request.new()
  let arg = request.getEnum(0, Priority)
  icEcho "Priority arg: ", arg
  reply(arg)

proc responsePriority*() {.query.} =
  echo "===== main.nim responsePriority() ====="
  let priority = Priority.High
  icEcho "Priority response: ", priority
  reply(priority)

proc argEcdsaCurveEnum*() {.query.} =
  echo "===== main.nim argEcdsaCurveEnum() ====="
  let request = Request.new()
  let arg = request.getEnum(0, EcdsaCurve)
  icEcho "EcdsaCurve enum arg: ", arg
  reply(arg)

proc responseEcdsaCurveEnum*() {.query.} =
  echo "===== main.nim responseEcdsaCurveEnum() ====="
  let curve = EcdsaCurve.secp256k1
  icEcho "EcdsaCurve enum response: ", curve
  reply(curve)

# ================================================================================
# Phase 3.1: Record内Enum値のCanister関数
# ================================================================================

proc argRecordWithEnum*() {.query.} =
  echo "===== main.nim argRecordWithEnum() ====="
  let request = Request.new()
  let recordArg = request.getVariant(0)
  
  # Record内のEnum値を取得（簡易バージョン）
  icEcho "Record variant tag: ", recordArg.tag
  icEcho "Record variant value: ", recordArg.value
  
  # 受け取ったVariantをそのまま返す
  reply(recordArg)

proc responseRecordWithEnum*() {.query.} =
  echo "===== main.nim responseRecordWithEnum() ====="
  
  # Enum値を含むRecordを作成
  # var recordResponse = newCRecord()
  # recordResponse["id"] = newCInt(12345)
  # recordResponse["name"] = newCText("Test Task")
  # recordResponse["status"] = SimpleStatus.Active  # Enum値の自動変換
  # recordResponse["priority"] = Priority.Critical
  # recordResponse["curve"] = EcdsaCurve.secp256r1
  # recordResponse["timestamp"] = newCText("2024-01-01T00:00:00Z")
  # let recordResponse = %*{
  #   "id": 12345,
  #   "name": "Test Task", 
  #   "status": SimpleStatus.Active,
  #   "priority": Priority.Critical,
  #   "curve": EcdsaCurve.secp256r1,
  #   "timestamp": "2024-01-01T00:00:00Z"
  # }
  
  # 一時的にシンプルなレスポンス
  let recordResponse = "Record with enum response temporarily disabled"
  
  icEcho "Record with enum response: ", recordResponse
  reply(recordResponse)

# ================================================================================
# Management Canister ECDSA連携テスト用関数（統合版）
# ================================================================================

proc responseEcdsaPublicKeyArgs() {.query.} =
  echo "===== main.nim responseEcdsaPublicKeyArgs() ====="
  try:
    # Motokoの仕様に基づくECDSA public key引数構造をシンプルなレスポンスで作成
    echo "Step 1: Creating ECDSA public key args structure"
    
    # シンプルなRecord構造でテスト
    var ecdsaArgs = newCRecord()
    
    # canister_id: opt principal = None
    ecdsaArgs["canister_id"] = ic_record.newCOptionNone()
    
    # derivation_path: vec blob = シンプルなデータ
    let testBlob = @[0x74u8, 0x65u8, 0x73u8, 0x74u8]  # "test"
    ecdsaArgs["derivation_path"] = newCBlob(testBlob)
    
    # key_id: record { curve: text, name: text } （variantの代わりにtextで一時的に）
    var keyIdRecord = newCRecord()
    keyIdRecord["curve"] = ic_record.newCText("secp256k1")
    keyIdRecord["name"] = ic_record.newCText("dfx_test_key")
    ecdsaArgs["key_id"] = keyIdRecord
    
    echo "Step 2: ECDSA structure created successfully"
    icEcho "ECDSA Args: ", ecdsaArgs
    
    reply(ecdsaArgs)
    
  except Exception as e:
    echo "Error in responseEcdsaPublicKeyArgs: ", e.msg
    reply("Error: " & e.msg)

# ================================================================================
# 既存の関数（変更なし）
# ================================================================================

proc greet() {.query.} =
  let caller = Msg.caller()
  icEcho "caller: ", caller
  let reqest = Request.new()
  let msg = reqest.getStr(0)
  let response = "Hello, " & msg & "!"
  reply(response)


proc requestAndResponse() {.query.} =
  let request = Request.new()
  let boolArg = request.getBool(0)
  let natArg = request.getNat(1)
  let intArg = request.getInt(2)
  let floatArg = request.getFloat(3)
  let textArg = request.getStr(4)

  icEcho "boolArg: ", boolArg
  icEcho "natArg: ", natArg
  icEcho "intArg: ", intArg
  icEcho "floatArg: ", floatArg
  icEcho "textArg: ", textArg
  icEcho "あいうえお"

  let msg = "requestAndResponse"
  reply(msg)


proc argBool() {.query.} =
  let request = Request.new()
  let arg = request.getBool(0)
  icEcho "arg: ", arg
  reply(arg)


proc argInt() {.query.} =
  let request = Request.new()
  let arg = request.getInt(0)
  icEcho "arg: ", arg
  reply(arg)


proc argNat() {.query.} =
  let request = Request.new()
  let arg = request.getNat(0)
  icEcho "arg: ", arg
  reply(arg)


proc argFloat() {.query.} =
  let request = Request.new()
  let arg = request.getFloat(0)
  icEcho "arg: ", arg
  reply(arg)


proc argText() {.query.} =
  let request = Request.new()
  let arg = request.getStr(0)
  icEcho "arg: ", arg
  reply(arg)


proc msgPrincipal() {.query.} =
  let caller = Msg.caller()
  reply(caller)


proc responseEmpty() {.query.} =
  reply()


proc responseRecord() {.query.} =
  echo "===== main.nim responseRecord() ====="
  # Phase 3.2で実装予定 - 関数名競合問題解決後に有効化
  var record = newCRecord()
  record["name"] = ic_record.newCText("John")
  record["age"] = ic_record.newCIntRecord(30)
  echo "record: ", $record
  reply(record)


proc responseNull() {.query.} =
  echo "===== main.nim responseNull() ====="
  reply()


proc argNat8() {.query.} =
  echo "===== main.nim argNat8() ====="
  let request = Request.new()
  let arg = request.getNat8(0)
  icEcho "arg: ", arg
  reply(arg)


proc argNat16() {.query.} =
  echo "===== main.nim argNat16() ====="
  let request = Request.new()
  let arg = request.getNat16(0)
  icEcho "arg: ", arg
  reply(arg)


proc argNat32() {.query.} =
  echo "===== main.nim argNat32() ====="
  let request = Request.new()
  let arg = request.getNat32(0)
  icEcho "arg: ", arg
  reply(arg)


proc argNat64() {.query.} =
  echo "===== main.nim argNat64() ====="
  let request = Request.new()
  let arg = request.getNat64(0)
  icEcho "arg: ", arg
  reply(arg)


proc argInt8() {.query.} =
  echo "===== main.nim argInt8() ====="
  let request = Request.new()
  let arg = request.getInt8(0)
  icEcho "arg: ", arg
  reply(arg)


proc argInt16() {.query.} =
  echo "===== main.nim argInt16() ====="
  let request = Request.new()
  let arg = request.getInt16(0)
  icEcho "arg: ", arg
  reply(arg)


proc argInt32() {.query.} =
  echo "===== main.nim argInt32() ====="
  let request = Request.new()
  let arg = request.getInt32(0)
  icEcho "arg: ", arg
  reply(arg)


proc argInt64() {.query.} =
  echo "===== main.nim argInt64() ====="
  let request = Request.new()
  let arg = request.getInt64(0)
  icEcho "arg: ", arg
  reply(arg)


proc argFloat32() {.query.} =
  echo "===== main.nim argFloat32() ====="
  let request = Request.new()
  let arg = request.getFloat32(0)
  icEcho "arg: ", arg
  reply(arg)


proc argFloat64() {.query.} =
  echo "===== main.nim argFloat64() ====="
  let request = Request.new()
  let arg = request.getFloat64(0)
  icEcho "arg: ", arg
  reply(arg)


proc argPrincipal() {.query.} =
  echo "===== main.nim argPrincipal() ====="
  let caller = Msg.caller()
  icEcho "caller: ", caller
  reply(caller)


proc argBlob() {.query.} =
  echo "===== main.nim argBlob() ====="
  let request = Request.new()
  let arg = request.getBlob(0)
  icEcho "arg length: ", arg.len
  icEcho "arg: ", arg
  reply(arg)


proc responseBlob() {.query.} =
  echo "===== main.nim responseBlob() ====="
  # テスト用のblobデータを返す（"Hello World"のUTF-8バイト列）
  let blobData = @[0x48u8, 0x65u8, 0x6Cu8, 0x6Cu8, 0x6Fu8, 0x20u8, 0x57u8, 0x6Fu8, 0x72u8, 0x6Cu8, 0x64u8]
  icEcho "response blob length: ", blobData.len
  reply(blobData)


proc argOpt() {.query.} =
  echo "===== main.nim argOpt() ====="
  let request = Request.new()
  # Option[uint8]として受け取る例
  let arg = request.getOpt(0, proc(r: Request, i: int): uint8 = r.getNat8(i))
  icEcho "arg isSome: ", arg.isSome()
  if arg.isSome():
    icEcho "arg value: ", arg.get()
  reply(arg)


proc responseOpt() {.query.} =
  echo "===== main.nim responseOpt() ====="
  # テスト用のOptionデータを返す（Some(42)）
  let optData = some(uint8(42))
  icEcho "response opt isSome: ", optData.isSome()
  if optData.isSome():
    icEcho "response opt value: ", optData.get()
  reply(optData)


proc argVec() {.query.} =
  echo "===== main.nim argVec() ====="
  let request = Request.new()
  let arg = request.getVec(0)
  icEcho "arg length: ", arg.len
  icEcho "arg: ", arg
  reply(arg)


proc responseVec() {.query.} =
  echo "===== main.nim responseVec() ====="
  # テスト用のVectorデータを返す（[100, 200, 300]のnat16）
  let vecData = @[
    newCandidValue(uint16(100)),
    newCandidValue(uint16(200)),
    newCandidValue(uint16(300))
  ]
  icEcho "response vec length: ", vecData.len
  reply(vecData)


proc argVariant() {.query.} =
  echo "===== main.nim argVariant() ====="
  let request = Request.new()
  let arg = request.getVariant(0)
  icEcho "arg tag: ", arg.tag
  icEcho "arg value: ", arg.value
  reply(arg)


proc argEcdsaCurve() {.query.} =
  echo "===== main.nim argEcdsaCurve() ====="
  let request = Request.new()
  let arg = request.getVariant(0)
  icEcho "ECDSA curve tag: ", arg.tag
  icEcho "ECDSA curve value: ", arg.value
  
  # ECDSA curveのvariant処理
  if arg.tag == candidHash("secp256k1"):
    icEcho "Received: secp256k1 curve"
  elif arg.tag == candidHash("secp256r1"):
    icEcho "Received: secp256r1 curve"
  else:
    icEcho "Unknown ECDSA curve tag: ", arg.tag
  
  reply(arg)


proc responseVariant() {.query.} =
  echo "===== main.nim responseVariant() ====="
  # テスト用のVariantデータを返す（success variant with text）
  let variantData = CandidVariant(
    tag: candidHash("success"),
    value: newCandidText("Operation completed successfully")
  )
  icEcho "response variant tag: ", variantData.tag
  icEcho "response variant value: ", variantData.value
  reply(variantData)


proc argFunc() {.query.} =
  echo "===== main.nim argFunc() ====="
  let request = Request.new()
  let arg = request.getFunc(0)
  icEcho "arg principal: ", arg.principal
  icEcho "arg method: ", arg.methodName
  reply(arg)


proc responseFunc() {.query.} =
  echo "===== main.nim responseFunc() ====="
  # Phase 3.2で実装予定 - Principal関連の競合問題解決後に有効化
  # テスト用のFunc参照を返す（management canisterのraw_rand）
  reply("func_feature_disabled_for_phase3")


# proc argNestedRecord() {.query.} =
#   echo "===== main.nim argNestedRecord() ====="
#   let request = Request.new()
#   let arg = request.getRecord(0)
#   icEcho "arg: ", arg
#   # ネストしたRecordをそのまま返す
#   reply(arg)


proc responseNestedRecord() {.query.} =
  echo "===== main.nim responseNestedRecord() START ====="
  
  try:
    # シンプルなRecord構造で確実に動作させる（ネストなし）
    echo "Step 1: Creating simple record structure..."
    
    var record = newCRecord()
    record["name"] = ic_record.newCText("Alice")
    record["age"] = newCInt(30)
    record["isActive"] = newCBool(true)
    echo "Step 2: Simple record created"
    
    echo "Step 3: About to call reply function..."
    reply(record)
    echo "Step 4: Reply successful"
    
  except CatchableError as e:
    echo "Error at step: ", e.msg
    echo "Error type: ", $e.name
    reply("Detailed error: " & e.msg & " (Type: " & $e.name & ")")
  
  echo "===== main.nim responseNestedRecord() END ====="


proc responseDeepNestedRecord() {.query.} =
  echo "===== main.nim responseDeepNestedRecord() ====="
  # より深くネストしたRecordを返す - 一時的に無効化（%*マクロのint型問題）
  # let deepRecord = %*{
  #   "organization": {
  #     "name": "Tech Corp",
  #     "departments": {
  #       "engineering": {
  #         "name": "Engineering",
  #         "team": {
  #           "frontend": {
  #             "name": "Frontend Team",
  #             "members": 5
  #           },
  #           "backend": {
  #             "name": "Backend Team",
  #             "members": 7
  #           }
  #         }
  #       }
  #     }
  #   }
  # }
  # icEcho "response deep nested record: ", deepRecord
  # reply(deepRecord)
  reply("Deep nested record temporarily disabled for ECDSA testing")


proc responseComplexNestedRecord() {.query.} =
  echo "===== main.nim responseComplexNestedRecord() ====="
  # Phase 3.2で実装予定 - Principal/Blob関連の競合問題解決後に有効化
  reply("complex_record_feature_disabled_for_phase3")
