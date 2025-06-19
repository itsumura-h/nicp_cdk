import std/unittest
import std/options
import ../../../src/nicp_cdk/ic_types/candid_types
import ../../../src/nicp_cdk/ic_types/ic_record
import ../../../src/nicp_cdk/ic_types/ic_principal
import ../../../src/nicp_cdk/ic_types/candid_funcs
import ../../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../../src/nicp_cdk/ic_types/candid_message/candid_decode

suite "Record型でOption型を扱う高度なテスト":
  
  test "Option型のCandidメッセージエンコード・デコード":
    # Option型を含むRecordを作成
    var record = newCRecord()
    
    let someValue = CandidValue(kind: ctOpt, optVal: some(newCandidValue("test")))
    let noneValue = CandidValue(kind: ctOpt, optVal: none(CandidValue))
    
    record["text"] = someValue
    record["empty"] = noneValue
    
    # CandidRecordをCandidValueに変換
    let recordValue = candid_funcs.toCandidValue(record)
    
    # エンコード
    let encoded = encodeCandidMessage(@[recordValue])
    check encoded.len > 0
    
    # デコード
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    
    # デコード結果の確認
    let decodedRecord = fromCandidValue(decoded.values[0])
    check decodedRecord.contains("text")
    check decodedRecord.contains("empty")
    
    let textField = decodedRecord["text"]
    let emptyField = decodedRecord["empty"]
    
    check textField.isSome()
    check emptyField.isNone()
    
    if textField.isSome():
      check textField.getOpt().getStr() == "test"

  test "Option[Principal]の特別なテスト（EcdsaPublicKeyArgs用）":
    # EcdsaPublicKeyArgsで使用されるcanister_id : opt canister_idパターン
    let managementCanister = Principal.fromText("aaaaa-aa")
    let userCanister = Principal.fromText("w7x7r-cok77-xa")
    
    # Some(Principal)のケース
    let somePrincipal = CandidValue(kind: ctOpt, optVal: some(newCandidValue(managementCanister)))
    # None Principal のケース
    let nonePrincipal = CandidValue(kind: ctOpt, optVal: none(CandidValue))
    
    var ecdsaArgsRecord1 = newCRecord()
    ecdsaArgsRecord1["canister_id"] = somePrincipal
    
    var ecdsaArgsRecord2 = newCRecord()
    ecdsaArgsRecord2["canister_id"] = nonePrincipal
    
    # 検証
    let field1 = ecdsaArgsRecord1["canister_id"]
    let field2 = ecdsaArgsRecord2["canister_id"]
    
    check field1.isSome()
    check field2.isNone()
    
    if field1.isSome():
      let principalValue = field1.getOpt()
      check candid_funcs.isPrincipal(principalValue)
      check principalValue.getPrincipal() == managementCanister

  test "ネストしたRecord内のOption型":
    # ネストしたRecord構造でのOption型
    var innerRecord = newCRecord()
    innerRecord["name"] = CandidValue(kind: ctOpt, optVal: some(newCandidValue("inner")))
    innerRecord["value"] = CandidValue(kind: ctOpt, optVal: none(CandidValue))
    
    var outerRecord = newCRecord()
    outerRecord["nested"] = candid_funcs.toCandidValue(innerRecord)
    outerRecord["flag"] = CandidValue(kind: ctOpt, optVal: some(newCandidValue(true)))
    
    # 検証
    let nestedField = outerRecord["nested"]
    check candid_funcs.isRecord(nestedField)
    
    let nestedRecord = fromCandidValue(candid_funcs.toCandidValue(nestedField))
    let nameField = nestedRecord["name"]
    let valueField = nestedRecord["value"]
    
    check nameField.isSome()
    check valueField.isNone()
    
    if nameField.isSome():
      check nameField.getOpt().getStr() == "inner"

  test "Option型を含む配列の複雑なパターン":
    # Option[Text], Option[Principal], Option[Int]の混在配列
    let optText = CandidValue(kind: ctOpt, optVal: some(newCandidValue("text")))
    let optPrincipal = CandidValue(kind: ctOpt, optVal: some(newCandidValue(Principal.fromText("aaaaa-aa"))))
    let optInt = CandidValue(kind: ctOpt, optVal: some(newCandidValue(42)))
    let noneValue = CandidValue(kind: ctOpt, optVal: none(CandidValue))
    
    let mixedArray = CandidValue(kind: ctVec, vecVal: @[optText, optPrincipal, optInt, noneValue])
    
    var record = newCRecord()
    record["mixed_options"] = mixedArray
    
    # 検証
    let arrayField = record["mixed_options"]
    check arrayField.len() == 4
    
    # Text Option
    check arrayField[0].isSome()
    if arrayField[0].isSome():
      check arrayField[0].getOpt().getStr() == "text"
    
    # Principal Option
    check arrayField[1].isSome()
    if arrayField[1].isSome():
      check candid_funcs.isPrincipal(arrayField[1].getOpt())
      check arrayField[1].getOpt().getPrincipal() == Principal.fromText("aaaaa-aa")
    
    # Int Option
    check arrayField[2].isSome()
    if arrayField[2].isSome():
      check arrayField[2].getOpt().getInt() == 42
    
    # None Option
    check arrayField[3].isNone()

  test "Option型の型安全性テスト":
    # 型の不一致をテストする
    let someInt = CandidValue(kind: ctOpt, optVal: some(newCandidValue(123)))
    
    var record = newCRecord()
    record["number"] = someInt
    
    let numberField = record["number"]
    check numberField.isSome()
    
    if numberField.isSome():
      let value = numberField.getOpt()
      check value.getInt() == 123
      
      # 間違った型での取得はエラーになることを確認
      expect(ValueError):
        discard value.getStr()
      
      expect(ValueError):
        discard value.getPrincipal()

  test "Option型のデフォルト値処理":
    # 存在しないフィールドに対するデフォルト処理
    var record = newCRecord()
    record["existing"] = CandidValue(kind: ctOpt, optVal: some(newCandidValue("exists")))
    
    # 存在するフィールド
    if record.contains("existing"):
      let field = record["existing"]
      check field.isSome()
      if field.isSome():
        check field.getOpt().getStr() == "exists"
    
    # 存在しないフィールドの安全なアクセス
    let defaultField = record.get("nonexistent", newCOptionNone())
    check defaultField.isNone()

  test "複数のOption型フィールドを持つ大きなRecord":
    # EcdsaPublicKeyArgsのような複合構造のテスト
    var record = newCRecord()
    
    # canister_id: opt Principal
    record["canister_id"] = CandidValue(kind: ctOpt, optVal: some(newCandidValue(Principal.fromText("aaaaa-aa"))))
    
    # optional_text: opt Text
    record["optional_text"] = CandidValue(kind: ctOpt, optVal: none(CandidValue))
    
    # optional_number: opt Nat
    record["optional_number"] = CandidValue(kind: ctOpt, optVal: some(newCandidValue(uint(42))))
    
    # required_field: Text (非Option)
    record["required_field"] = newCandidValue("required")
    
    # 全フィールドの検証
    check record.len() == 4
    check record.contains("canister_id")
    check record.contains("optional_text")
    check record.contains("optional_number")
    check record.contains("required_field")
    
    # Option型フィールドの検証
    check record["canister_id"].isSome()
    check record["optional_text"].isNone()
    check record["optional_number"].isSome()
    
    # 非Option型フィールドの検証
    let requiredField = record["required_field"]
    check requiredField.getStr() == "required"
    
    # 値の取得テスト
    if record["canister_id"].isSome():
      check record["canister_id"].getOpt().getPrincipal() == Principal.fromText("aaaaa-aa")
    
    if record["optional_number"].isSome():
      # natVal として uint で取得
      let numValue = record["optional_number"].getOpt()
      # CandidRecordからuintの値を取得する適切な方法を使用
      when numValue is CandidRecord:
        case numValue.kind:
        of ckInt:
          check numValue.intVal == 42
        else:
          check false  # 期待される型ではない
      else:
        check false  # CandidRecordではない 