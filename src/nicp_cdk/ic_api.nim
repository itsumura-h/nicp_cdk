import std/strutils
import ./ic0/ic0

proc icEcho*[T](x: varargs[T, `$`]) =
  let msg = x.join()
  let cMsg = msg.cstring
  ic0_debug_print(cast[int](cMsg), cMsg.len)

template devEcho*(x: varargs[untyped]) =
  when not defined(release):
    icEcho(x)
