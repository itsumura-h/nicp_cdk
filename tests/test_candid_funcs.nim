import unittest
import ../src/nicp_cdk/ic_types/candid_funcs
import ../src/nicp_cdk/ic_types/candid_types
import ../src/nicp_cdk/ic_types/ic_principal

suite "candid_funcs basic conversion tests":
  test "bool conversion roundtrip":
    let original = true
    let cv = toCandidValue(original)
    let converted = toBool(cv)
    check converted == original
    check isBool(cv)
  
  test "string conversion roundtrip":
    let original = "hello world"
    let cv = toCandidValue(original)
    let converted = toString(cv)
    check converted == original
    check isText(cv)
  
  test "int conversion roundtrip":
    let original = 42
    let cv = toCandidValue(original)
    let converted = toInt(cv)
    check converted == original
    check isInt(cv)
  
  test "uint conversion roundtrip":
    let original = 123'u
    let cv = toCandidValue(original)
    let converted = toUInt(cv)
    check converted == original
    check isNat(cv)
  
  test "float32 conversion roundtrip":
    let original = 3.14'f32
    let cv = toCandidValue(original)
    let converted = toFloat32(cv)
    check converted == original
    check isFloat32(cv)
  
  test "float64 conversion roundtrip":
    let original = 2.718
    let cv = toCandidValue(original)
    let converted = toFloat64(cv)
    check converted == original
    check isFloat64(cv)
  
  test "Principal conversion roundtrip":
    let original = Principal.fromText("aaaaa-aa")
    let cv = toCandidValue(original)
    let converted = toPrincipal(cv)
    check converted.value == original.value
    check converted.bytes == original.bytes
    check isPrincipal(cv)
  
  test "blob conversion roundtrip":
    let original = @[1'u8, 2'u8, 3'u8, 4'u8]
    let cv = toCandidValue(original)
    let converted = toBlob(cv)
    check converted == original
    check isBlob(cv)
  
  test "type checking for null":
    let cv = CandidValue(kind: ctNull)
    check isNull(cv)
    check not isBool(cv)
    check not isText(cv)
  
  test "error handling for wrong type":
    let cv = toCandidValue(true)
    expect(ValueError):
      discard toString(cv)  # boolをstringとして取得しようとするとエラー

suite "candid_funcs CandidRecord conversion tests":
  test "CandidValue to CandidRecord conversion":
    let cv = toCandidValue("test string")
    let cr = fromCandidValue(cv)
    check cr.kind == ckText
    check cr.strVal == "test string"
  
  test "CandidRecord to CandidValue conversion":
    let cr = CandidRecord(kind: ckBool, boolVal: true)
    let cv = toCandidValue(cr)
    check cv.kind == ctBool
    check cv.boolVal == true
  
  test "round trip CandidValue <-> CandidRecord":
    let originalCV = toCandidValue(42)
    let cr = fromCandidValue(originalCV)
    let convertedCV = toCandidValue(cr)
    
    check originalCV.kind == convertedCV.kind
    check originalCV.intVal == convertedCV.intVal

suite "candid_funcs Variant functions tests":
  test "Variant type checking functions":
    # 偽のVariantレコードを作成してテスト
    let cv = CandidRecord(
      kind: ckVariant, 
      variantVal: CandidVariant(tag: candidHash("success"), value: toCandidValue(true))
    )
    
    check isResultVariant(cv)
    check not isOptionVariant(cv)
  
  test "Option variant checking":
    let cv = CandidRecord(
      kind: ckVariant, 
      variantVal: CandidVariant(tag: candidHash("some"), value: toCandidValue("test"))
    )
    
    check isOptionVariant(cv)
    check not isResultVariant(cv) 