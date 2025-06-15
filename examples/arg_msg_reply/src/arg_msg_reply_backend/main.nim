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
