import nicp_cdk
import nicp_cdk/ic_types/ic_text

proc boolFunc() {.query.} =
  reply(true)


proc intFunc() {.query.} =
  reply(1)


proc int8Func() {.query.} =
  reply(1'i8)


proc int16Func() {.query.} =
  reply(1'i16)


proc int32Func() {.query.} =
  reply(1'i32)


proc int64Func() {.query.} =
  reply(1'i64)


proc natFunc() {.query.} =
  reply(1'u)


proc nat8Func() {.query.} =
  reply(1'u8)


proc nat16Func() {.query.} =
  reply(1'u16)


proc nat32Func() {.query.} =
  reply(1'u32)


proc nat64Func() {.query.} =
  reply(1'u64)


proc floatFunc() {.query.} =
  reply(1.0'f64)


proc textFunc() {.query.} =
  reply("Hello, World!")


proc blobFunc() {.query.} =
  let data = toBlob("Hello, World!")
  reply(data)


proc responseNull() {.query.} =
  reply(nil)


proc responseEmpty() {.query.} =
  reply()
