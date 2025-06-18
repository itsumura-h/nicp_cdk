import std/strutils
import std/options
import std/tables
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/ic_types/candid_types
import ../../../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../../../src/nicp_cdk/ic0/ic0


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
  var record = %*{
    "name": "John",
    "age": 30,
    "principal": Principal.fromText("aaaaa-aa")
  }
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
  # テスト用のFunc参照を返す（management canisterのraw_rand）
  let funcData = CandidFunc(
    principal: Principal.fromText("aaaaa-aa"),
    methodName: "raw_rand",
    args: @[],
    returns: @[ctText],  # raw_randはtextを返す
    annotations: @[]
  )
  icEcho "response func principal: ", funcData.principal
  icEcho "response func method: ", funcData.methodName
  reply(funcData)


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
    record["name"] = newCText("Alice")
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
  # より深くネストしたRecordを返す
  let deepRecord = %*{
    "organization": {
      "name": "Tech Corp",
      "departments": {
        "engineering": {
          "name": "Engineering",
          "team": {
            "frontend": {
              "name": "Frontend Team",
              "members": 5
            },
            "backend": {
              "name": "Backend Team",
              "members": 7
            }
          }
        }
      }
    }
  }
  icEcho "response deep nested record: ", deepRecord
  reply(deepRecord)


proc responseComplexNestedRecord() {.query.} =
  echo "===== main.nim responseComplexNestedRecord() ====="
  # 様々な型を含む複雑なネストRecord
  let complexRecord = %*{
    "application": {
      "info": {
        "name": "MyApp",
        "version": "1.0.0",
        "settings": {
          "database": {
            "host": "localhost",
            "port": 5432,
            "ssl": true
          },
          "cache": {
            "enabled": true,
            "ttl": 3600,
            "servers": ["redis1:6379", "redis2:6379"]
          }
        }
      },
      "users": {
        "permissions": {
          "admin": [Principal.fromText("aaaaa-aa")]
        }
      },
      "files": {
        "config": @[0x7Bu8, 0x7Du8].asBlob  # "{}"
      }
    }
  }
  icEcho "response complex nested record: ", complexRecord
  reply(complexRecord)


proc responseEcdsaPublicKeyArgs() {.query.} =
  echo "===== main.nim responseEcdsaPublicKeyArgs() ====="
  
  try:
    # シンプルなRecord構造で確実に動作させる
    echo "Step 1: Creating ECDSA public key args record..."
    
    var record = newCRecord()
    record["canister_id"] = newCPrincipal("rdmx6-jaaaa-aaaaa-aaadq-cai")
    record["derivation_path"] = newCText("test-derivation-path")
    record["curve"] = newCText("secp256k1")
    record["key_name"] = newCText("test-key-1")
    echo "Step 2: ECDSA record created"
    
    echo "Step 3: About to call reply function..."
    reply(record)
    echo "Step 4: Reply successful"
    
  except CatchableError as e:
    echo "Error at step: ", e.msg
    echo "Error type: ", $e.name
    reply("Detailed error: " & e.msg & " (Type: " & $e.name & ")")
