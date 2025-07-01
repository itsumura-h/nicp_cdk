import std/asyncmacro
import std/asyncfutures
import std/strutils

# -----------------------------------------------------------------------------
#  async/await を再エクスポート
# -----------------------------------------------------------------------------
export asyncmacro, asyncfutures

# -----------------------------------------------------------------------------
#  ICP System API とのブリッジ
# -----------------------------------------------------------------------------

import ../ic0/ic0
import ../reply  # 既存の reply プロシージャ群を利用
import ../ic_types/candid_types  # ptrToInt を利用

export reply  # ライブラリを使う側で `reply()` が見えるように再エクスポート

# -----------------------------------------------------------------------------
#  reject(_: string) ― Candid Text を返してエラー応答
# -----------------------------------------------------------------------------

proc reject*(message: string) {.noreturn, inline.} =
  ## 指定したメッセージで現在の呼び出しを reject する。
  ##
  ##   * message: UTF-8 文字列をそのままエラー本文として送信します。
  ##
  ## 返り値はなく、呼び出し後は Wasm 実行が trap します（戻ってこない）。
  ic0_msg_reject(ptrToInt(addr message[0]), message.len)

# -----------------------------------------------------------------------------
#  便利関数: reject で数値や bool などを送る場合は文字列化して reject
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
