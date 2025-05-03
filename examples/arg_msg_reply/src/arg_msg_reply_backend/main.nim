import std/strutils
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
  icEcho caller
  reply(caller)


proc responseEmpty() {.query.} =
  reply()
