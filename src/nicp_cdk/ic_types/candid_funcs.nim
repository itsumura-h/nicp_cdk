## candid_funcs.nim
## 
## Candid型変換関数を集約するモジュール
## ic_*型からCandidValueへの変換とその逆変換を提供
##

# 未使用のimportは削除済み

import ./candid_types
import ./ic_principal

# CandidRecordタイプの前方宣言（ic_record.nimに移動済み）

# ================================================================================
# 基本型からCandidValueへの変換関数
# ================================================================================

proc toCandidValue*(value: bool): CandidValue =
  ## bool型をCandidValueに変換
  CandidValue(kind: ctBool, boolVal: value)

proc toCandidValue*(value: string): CandidValue =
  ## string型をCandidValueに変換
  CandidValue(kind: ctText, textVal: value)

proc toCandidValue*(value: int): CandidValue =
  ## int型をCandidValueに変換
  CandidValue(kind: ctInt, intVal: value)

proc toCandidValue*(value: uint): CandidValue =
  ## uint型をCandidValueに変換
  CandidValue(kind: ctNat, natVal: value)

proc toCandidValue*(value: float32): CandidValue =
  ## float32型をCandidValueに変換
  CandidValue(kind: ctFloat32, float32Val: value)

proc toCandidValue*(value: float64): CandidValue =
  ## float64型をCandidValueに変換
  CandidValue(kind: ctFloat64, float64Val: value)

proc toCandidValue*(value: Principal): CandidValue =
  ## Principal型をCandidValueに変換
  CandidValue(kind: ctPrincipal, principalVal: value)

proc toCandidValue*(value: seq[uint8]): CandidValue =
  ## バイト配列をCandidValueに変換
  CandidValue(kind: ctBlob, blobVal: value)

# ================================================================================
# CandidValueから基本型への変換関数
# ================================================================================

proc toBool*(cv: CandidValue): bool =
  ## CandidValueからbool型に変換
  if cv.kind != ctBool:
    raise newException(ValueError, "Expected bool type")
  cv.boolVal

proc toString*(cv: CandidValue): string =
  ## CandidValueからstring型に変換
  if cv.kind != ctText:
    raise newException(ValueError, "Expected text type")
  cv.textVal

proc toInt*(cv: CandidValue): int =
  ## CandidValueからint型に変換
  if cv.kind != ctInt:
    raise newException(ValueError, "Expected int type")
  cv.intVal

proc toUInt*(cv: CandidValue): uint =
  ## CandidValueからuint型に変換
  if cv.kind != ctNat:
    raise newException(ValueError, "Expected nat type")
  cv.natVal

proc toFloat32*(cv: CandidValue): float32 =
  ## CandidValueからfloat32型に変換
  if cv.kind != ctFloat32:
    raise newException(ValueError, "Expected float32 type")
  cv.float32Val

proc toFloat64*(cv: CandidValue): float64 =
  ## CandidValueからfloat64型に変換
  if cv.kind != ctFloat64:
    raise newException(ValueError, "Expected float64 type")
  cv.float64Val

proc toPrincipal*(cv: CandidValue): Principal =
  ## CandidValueからPrincipal型に変換
  if cv.kind != ctPrincipal:
    raise newException(ValueError, "Expected principal type")
  cv.principalVal

proc toBlob*(cv: CandidValue): seq[uint8] =
  ## CandidValueからバイト配列に変換
  if cv.kind != ctBlob:
    raise newException(ValueError, "Expected blob type")
  cv.blobVal

# ================================================================================
# 型判定ヘルパー関数
# ================================================================================

proc isBool*(cv: CandidValue): bool =
  ## CandidValueがbool型かどうか判定
  cv.kind == ctBool

proc isText*(cv: CandidValue): bool =
  ## CandidValueがtext型かどうか判定
  cv.kind == ctText

proc isInt*(cv: CandidValue): bool =
  ## CandidValueがint型かどうか判定
  cv.kind == ctInt

proc isNat*(cv: CandidValue): bool =
  ## CandidValueがnat型かどうか判定
  cv.kind == ctNat

proc isFloat32*(cv: CandidValue): bool =
  ## CandidValueがfloat32型かどうか判定
  cv.kind == ctFloat32

proc isFloat64*(cv: CandidValue): bool =
  ## CandidValueがfloat64型かどうか判定
  cv.kind == ctFloat64

proc isPrincipal*(cv: CandidValue): bool =
  ## CandidValueがprincipal型かどうか判定
  cv.kind == ctPrincipal

proc isBlob*(cv: CandidValue): bool =
  ## CandidValueがblob型かどうか判定
  cv.kind == ctBlob

proc isNull*(cv: CandidValue): bool =
  ## CandidValueがnull型かどうか判定
  cv.kind == ctNull
