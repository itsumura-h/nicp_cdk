import std/strutils
import std/options
import ../../../../src/nicp_cdk


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
  let request = Request.new()
  let arg = request.getPrincipal(0)
  icEcho "arg: ", arg
  reply(arg)


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
