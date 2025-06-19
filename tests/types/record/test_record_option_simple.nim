import std/unittest
import std/options
import ../../../src/nicp_cdk/ic_types/candid_types
import ../../../src/nicp_cdk/ic_types/ic_record
import ../../../src/nicp_cdk/ic_types/ic_principal
import ../../../src/nicp_cdk/ic_types/candid_funcs

suite "Record型でOption型を扱うテスト":
  
  test "基本的なOption型の作成と取得":
    # CandidRecordを手動で作成
    var record = newCRecord()
    
    # Option型のCandidValueを作成
    let someNickname = CandidValue(kind: ctOpt, optVal: some(newCandidValue("Ali")))
    let noneMiddleName = CandidValue(kind: ctOpt, optVal: none(CandidValue))
    let someAge = CandidValue(kind: ctOpt, optVal: some(newCandidValue(25)))
    
    # CandidValueを直接フィールドに設定
    record["nickname"] = someNickname
    record["middleName"] = noneMiddleName
    record["age"] = someAge
    
    # フィールドが正しく設定されているか確認
    check record.contains("nickname")
    check record.contains("middleName") 
    check record.contains("age")
    
    # Option値の取得とチェック
    let nicknameField = record["nickname"]
    let middleNameField = record["middleName"]
    let ageField = record["age"]
    
    check nicknameField.isSome() == true
    check middleNameField.isNone() == true
    check ageField.isSome() == true
    
    # Some値から実際の値を取得
    if nicknameField.isSome():
      let nicknameValue = nicknameField.getOpt()
      check nicknameValue.getStr() == "Ali"
      
    if ageField.isSome():
      let ageValue = ageField.getOpt()
      check ageValue.getInt() == 25

  test "Option型の直接的な操作":
    # Option CandidValue を直接作成
    let someText = CandidValue(kind: ctOpt, optVal: some(newCandidValue("Hello")))
    let noneText = CandidValue(kind: ctOpt, optVal: none(CandidValue))
    let someInt = CandidValue(kind: ctOpt, optVal: some(newCandidValue(42)))
    
    # CandidRecordに変換して確認
    let textRecord = fromCandidValue(someText)
    let emptyRecord = fromCandidValue(noneText)
    let numberRecord = fromCandidValue(someInt)
    
    check textRecord.isSome() == true
    check emptyRecord.isNone() == true
    check numberRecord.isSome() == true
    
    if textRecord.isSome():
      check textRecord.getOpt().getStr() == "Hello"
      
    if numberRecord.isSome():
      check numberRecord.getOpt().getInt() == 42

  test "Option[Principal]の扱い":
    let principal = Principal.fromText("aaaaa-aa")
    let somePrincipal = CandidValue(kind: ctOpt, optVal: some(newCandidValue(principal)))
    let nonePrincipal = CandidValue(kind: ctOpt, optVal: none(CandidValue))
    
    var record = newCRecord()
    record["owner"] = somePrincipal
    record["manager"] = nonePrincipal
    
    let ownerRecord = record["owner"]
    let managerRecord = record["manager"]
    
    check ownerRecord.isSome() == true
    check managerRecord.isNone() == true
    
    if ownerRecord.isSome():
      check ownerRecord.getOpt().getPrincipal() == principal

  test "多重配列内のOption型":
    # Option型を含む配列をRecord内に持つ
    let someValue1 = CandidValue(kind: ctOpt, optVal: some(newCandidValue("first")))
    let noneValue = CandidValue(kind: ctOpt, optVal: none(CandidValue))
    let someValue2 = CandidValue(kind: ctOpt, optVal: some(newCandidValue("second")))
    
    let optionArray = CandidValue(kind: ctVec, vecVal: @[someValue1, noneValue, someValue2])
    
    var record = newCRecord()
    record["optionalStrings"] = optionArray
    
    # 配列をCandidRecordとして取得
    let arrayRecord = record["optionalStrings"]
    check arrayRecord.len() == 3
    
    # 各要素をチェック
    check arrayRecord[0].isSome() == true
    check arrayRecord[1].isNone() == true
    check arrayRecord[2].isSome() == true
    
    if arrayRecord[0].isSome():
      check arrayRecord[0].getOpt().getStr() == "first"
    if arrayRecord[2].isSome():
      check arrayRecord[2].getOpt().getStr() == "second" 