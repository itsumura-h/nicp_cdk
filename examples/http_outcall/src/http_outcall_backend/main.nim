import ../../../../src/nicp_cdk
import controller


proc greet() {.query.} =
  let request = Request.new()
  let name = request.getStr(0)
  reply("Hello, " & name & "!")

proc getRequest() {.update.} = discard controller.getRequest()