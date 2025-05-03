import ./ic0/ic0
import ./ic_types/candid
import ./ic_types/ic_empty
import ./ic_types/ic_bool
import ./ic_types/ic_int
import ./ic_types/ic_float
import ./ic_types/ic_text
import ./ic_types/ic_principal


proc reply*() =
  let response = serializeCandid()
  ic0_msg_reply_data_append(ptrToInt(addr response[0]), response.len)
  ic0_msg_reply()

proc reply*(msg: bool) =
  let response = serializeCandid(msg)
  ic0_msg_reply_data_append(ptrToInt(addr response[0]), response.len)
  ic0_msg_reply()

proc reply*(msg: int32) =
  let response = serializeCandid(msg)
  ic0_msg_reply_data_append(ptrToInt(addr response[0]), response.len)
  ic0_msg_reply()

# proc reply*(msg: int64) =
#   let response = serializeCandid(msg)
#   ic0_msg_reply_data_append(ptrToUint32(addr response[0]), uint32(response.len))
#   ic0_msg_reply()


proc reply*(msg: int) =
  let response = serializeCandid(msg)
  ic0_msg_reply_data_append(ptrToInt(addr response[0]), response.len)
  ic0_msg_reply()


proc reply*(msg: Natural) =
  let response = serializeCandid(msg)
  ic0_msg_reply_data_append(ptrToInt(addr response[0]), response.len)
  ic0_msg_reply()


proc reply*(msg: float32) =
  let response = serializeCandid(msg)
  ic0_msg_reply_data_append(ptrToInt(addr response[0]), response.len)
  ic0_msg_reply()

# proc reply*(msg: float64) =
#   let response = serializeCandid(msg)
#   ic0_msg_reply_data_append(ptrToUint32(addr response[0]), uint32(response.len))
#   ic0_msg_reply()

proc reply*(msg: string) =
  let response = serializeCandid(msg)
  ic0_msg_reply_data_append(ptrToInt(addr response[0]), response.len)
  ic0_msg_reply()


proc reply*(msg: Principal) =
  let response = serializeCandid(msg)
  ic0_msg_reply_data_append(ptrToInt(addr response[0]), response.len)
  ic0_msg_reply()
