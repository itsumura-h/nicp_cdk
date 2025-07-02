import std/asyncmacro
import std/asyncfutures
import std/strutils

# -----------------------------------------------------------------------------
#  Re-export async/await
# -----------------------------------------------------------------------------
export asyncmacro, asyncfutures

# -----------------------------------------------------------------------------
#  Bridge to ICP System API
# -----------------------------------------------------------------------------

import ../ic0/ic0
import ../reply  # Utilize existing reply procedures
import ../ic_types/candid_types  # Utilize ptrToInt

export reply  # Re-export so `reply()` is visible to library users

# -----------------------------------------------------------------------------
#  reject(_: string) - Respond with an error by returning Candid Text
# -----------------------------------------------------------------------------

proc reject*(message: string) {.noreturn, inline.} =
  ## Rejects the current call with the specified message.
  ##
  ##   * message: The UTF-8 string will be sent as the error body.
  ##
  ## This function does not return; Wasm execution will trap after its call.
  ic0_msg_reject(ptrToInt(addr message[0]), message.len)

# -----------------------------------------------------------------------------
#  Utility function: Reject with stringified numeric or boolean values
# -----------------------------------------------------------------------------

proc reject*(value: bool) {.inline, noreturn.} =
  reject($value)

proc reject*(value: int) {.inline, noreturn.} =
  reject($value)

proc reject*(value: uint) {.inline, noreturn.} =
  reject($value)

proc reject*(value: float32) {.inline, noreturn.} =
  reject($value)

proc reject*(value: float64) {.inline, noreturn.} =
  reject($value)
