discard """
cmd: "nim c --skipUserCfg tests/types/test_opt.nim"
"""
# nim c -r --skipUserCfg tests/types/test_opt.nim

import std/unittest
import std/options
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/ic_principal
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode

suite "ic_opt tests":
  test "encode with option some nat8":
    let someValue = newCandidValue(uint8(42))
    let optValue = newCandidOpt(some(someValue))
    let encoded = encodeCandidMessage(@[optValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル数(1バイト) + opt型テーブル(2バイト) + opt型の内部型(1バイト) + 型シーケンス(1バイト) + hasValue(1バイト) + 値(1バイト) = 11バイト
    check encoded.len == 11

  test "encode with option none":
    let optValue = newCandidOpt(none(CandidValue))
    let encoded = encodeCandidMessage(@[optValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル数(1バイト) + opt型テーブル(2バイト) + opt型の内部型(1バイト) + 型シーケンス(1バイト) + hasValue(1バイト) = 10バイト
    check encoded.len == 10

  test "encode with option some text":
    let textValue = newCandidValue("Hello")
    let optValue = newCandidOpt(some(textValue))
    let encoded = encodeCandidMessage(@[optValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル数(1バイト) + opt型テーブル(2バイト) + opt型の内部型(1バイト) + 型シーケンス(1バイト) + hasValue(1バイト) + 文字列長(1バイト) + 文字列データ(5バイト) = 16バイト
    check encoded.len == 16

  test "encode with option some bool":
    let boolValue = newCandidValue(true)
    let optValue = newCandidOpt(some(boolValue))
    let encoded = encodeCandidMessage(@[optValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル数(1バイト) + opt型テーブル(2バイト) + opt型の内部型(1バイト) + 型シーケンス(1バイト) + hasValue(1バイト) + bool値(1バイト) = 11バイト
    check encoded.len == 11

  test "encode and decode with option some nat":
    let someValue = newCandidValue(uint(12345))
    let optValue = newCandidOpt(some(someValue))
    let encoded = encodeCandidMessage(@[optValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctOpt
    check decoded.values[0].optVal.isSome()
    check decoded.values[0].optVal.get().kind == ctNat
    check decoded.values[0].optVal.get().natVal == 12345

  test "encode and decode with option none":
    let optValue = newCandidOpt(none(CandidValue))
    let encoded = encodeCandidMessage(@[optValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctOpt
    check decoded.values[0].optVal.isNone()

  test "encode and decode with option some text":
    let textValue = newCandidValue("Testing")
    let optValue = newCandidOpt(some(textValue))
    let encoded = encodeCandidMessage(@[optValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctOpt
    check decoded.values[0].optVal.isSome()
    check decoded.values[0].optVal.get().kind == ctText
    check decoded.values[0].optVal.get().textVal == "Testing"

  test "encode and decode with option some float64":
    let floatValue = newCandidValue(3.14159)
    let optValue = newCandidOpt(some(floatValue))
    let encoded = encodeCandidMessage(@[optValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctOpt
    check decoded.values[0].optVal.isSome()
    check decoded.values[0].optVal.get().kind == ctFloat64
    check decoded.values[0].optVal.get().float64Val == 3.14159

  test "multiple option values":
    let optValue1 = newCandidOpt(some(newCandidValue(uint8(1))))
    let optValue2 = newCandidOpt(none(CandidValue))
    let optValue3 = newCandidOpt(some(newCandidValue("test")))
    let encoded = encodeCandidMessage(@[optValue1, optValue2, optValue3])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 3
    check decoded.values[0].kind == ctOpt
    check decoded.values[0].optVal.isSome()
    check decoded.values[0].optVal.get().nat8Val == 1
    check decoded.values[1].kind == ctOpt
    check decoded.values[1].optVal.isNone()
    check decoded.values[2].kind == ctOpt
    check decoded.values[2].optVal.isSome()
    check decoded.values[2].optVal.get().textVal == "test"

  test "option value type check":
    let someValue = newCandidValue(int32(-1000))
    let optValue = newCandidOpt(some(someValue))
    check optValue.kind == ctOpt
    check optValue.optVal.isSome()
    check optValue.optVal.get().kind == ctInt32
    check optValue.optVal.get().int32Val == -1000

  test "option with principal":
    let principalValue = newCandidValue(Principal.fromText("aaaaa-aa"))
    let optValue = newCandidOpt(some(principalValue))
    let encoded = encodeCandidMessage(@[optValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctOpt
    check decoded.values[0].optVal.isSome()
    check decoded.values[0].optVal.get().kind == ctPrincipal
    check decoded.values[0].optVal.get().principalVal.value == "aaaaa-aa" 