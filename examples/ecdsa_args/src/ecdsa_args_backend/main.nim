import std/strutils
import std/options
import std/tables
import std/sequtils  # mapItのために追加
import ../../../../src/nicp_cdk
import ../../../../src/nicp_cdk/ic_types/candid_types
import ../../../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../../../src/nicp_cdk/ic_types/candid_funcs
import ../../../../src/nicp_cdk/ic_types/ic_record
import ../../../../src/nicp_cdk/ic0/ic0

# ================================================================================
# ECDSA関連型定義
# ================================================================================

type
  EcdsaCurve* {.pure.} = enum
    secp256k1 = 0
    secp256r1 = 1


# ================================================================================
# ECDSA Curve Enum関連関数
# ================================================================================

proc argEcdsaCurveEnum*() {.query.} =
  echo "===== ecdsa_args argEcdsaCurveEnum() ====="
  let request = Request.new()
  let arg = request.getEnum(0, EcdsaCurve)
  icEcho "EcdsaCurve enum arg: ", arg
  reply(arg)

proc responseEcdsaCurveEnum*() {.query.} =
  echo "===== ecdsa_args responseEcdsaCurveEnum() ====="
  let curve = EcdsaCurve.secp256k1
  icEcho "EcdsaCurve enum response: ", curve
  reply(curve)

proc argEcdsaCurve() {.query.} =
  echo "===== ecdsa_args argEcdsaCurve() ====="
  let request = Request.new()
  let arg = request.getVariant(0)
  icEcho "ECDSA curve tag: ", arg.tag
  icEcho "ECDSA curve value: ", arg.value
  
  # ECDSA curveのvariant処理
  if arg.tag == candidHash("secp256k1"):
    icEcho "Received: secp256k1 curve"
  elif arg.tag == candidHash("secp256r1"):
    icEcho "Received: secp256r1 curve"
  else:
    icEcho "Unknown ECDSA curve tag: ", arg.tag
  
  reply(arg)

# ================================================================================
# Management Canister ECDSA連携関数（統合版）
# ================================================================================

# Phase 2A: Motokoスタイルのecdsaarg関数実装（超簡略化版）
proc ecdsaArg() {.query.} =
  echo "===== ecdsa_args ecdsaArg() ====="
  try:
    echo "Step 1: Getting caller and converting to blob (Motoko style)"
    
    # 1. callerの取得（Motokoの msg.caller と同等）
    let caller = Msg.caller()
    icEcho "caller: ", caller
    
    # 2. callerをblobに変換（Motokoの Principal.toBlob(caller) と同等）
    let blobCallerBytes = caller.bytes  # seq[byte]
    let blobCaller = blobCallerBytes.mapIt(uint8(it))  # seq[uint8]に変換
    icEcho "blobCaller length: ", blobCaller.len
    icEcho "blobCaller: ", blobCaller
    
    # 3. 超簡略化: まずはテキストレスポンスのみ
    let response = "ECDSA caller blob length: " & $blobCaller.len & ", first bytes: [" & 
                   $blobCaller[0] & "," & $blobCaller[1] & "]"
    
    echo "Step 2: Basic caller → blob conversion successful"
    icEcho "Response: ", response
    
    reply(response)
    
  except Exception as e:
    echo "Error in ecdsaArg: ", e.msg
    reply("Error: " & e.msg)

proc responseEcdsaPublicKeyArgs() {.query.} =
  echo "===== ecdsa_args responseEcdsaPublicKeyArgs() ====="
  try:
    echo "Step 1: Creating ECDSA structure using working approach"
    
    # Use the same approach as responseSimpleRecord
    var ecdsaFields = initTable[string, CandidValue]()
    
    # Step 1: Add canister_id field - use null instead of none(CandidValue)
    ecdsaFields["canister_id"] = newCandidNull()
    
    # Step 2: Add derivation_path field
    let caller = Msg.caller()
    let blobCaller = caller.bytes.mapIt(uint8(it))
    let derivationPath = @[blobCaller]
    ecdsaFields["derivation_path"] = newCandidValue(derivationPath)
    
    # Step 3: Create key_id sub-record
    var keyIdFields = initTable[string, CandidValue]()
    keyIdFields["name"] = newCandidText("dfx_test_key")
    keyIdFields["curve"] = newCandidValue(EcdsaCurve.secp256k1)
    let keyIdRecord = newCandidRecord(keyIdFields)
    ecdsaFields["key_id"] = keyIdRecord
    
    # Step 4: Create final record
    let ecdsaRecord = newCandidRecord(ecdsaFields)
    
    echo "ECDSA structure created successfully using working approach"
    
    reply(ecdsaRecord)
    
  except Exception as e:
    echo "Error in responseEcdsaPublicKeyArgs: ", e.msg
    reply("Error: " & e.msg)

# ================================================================================
# ECDSA デバッグ・ステップ別テスト関数群
# ================================================================================

proc responseEcdsaDebug() {.query.} =
  echo "===== ecdsa_args responseEcdsaDebug() ====="
  try:
    echo "Step 1: Testing Principal.bytes"
    
    # Motokoリファレンス実装に基づく実装
    let caller = Msg.caller()
    icEcho "caller: ", caller
    
    # callerをblobに変換（Principal.bytesを使用）
    let blobCallerBytes = caller.bytes  # seq[byte]
    let blobCaller = blobCallerBytes.mapIt(uint8(it))  # seq[uint8]に変換
    icEcho "blobCaller length: ", blobCaller.len
    icEcho "blobCaller: ", blobCaller
    
    reply("Principal bytes debug completed")
    
  except Exception as e:
    echo "Error in responseEcdsaDebug: ", e.msg
    reply("Error: " & e.msg)

proc responseEcdsaStep1() {.query.} =
  echo "===== ecdsa_args responseEcdsaStep1() ====="
  try:
    echo "Step 1: Testing vec blob creation"
    
    # Principal.bytes取得
    let caller = Msg.caller()
    let blobCallerBytes = caller.bytes
    let blobCaller = blobCallerBytes.mapIt(uint8(it))
    
    # vec blobの作成テスト
    let derivationPath = @[blobCaller]  # seq[seq[uint8]]
    let vecBlobValue = newCandidValue(derivationPath)
    
    icEcho "Vec blob created successfully: ", vecBlobValue.kind
    reply("Vec blob creation successful")
    
  except Exception as e:
    echo "Error in responseEcdsaStep1: ", e.msg
    reply("Error: " & e.msg)

proc responseEcdsaStep2() {.query.} =
  echo "===== ecdsa_args responseEcdsaStep2() ====="
  try:
    echo "Step 2: Creating simple blob using unified processing"
    
    let caller = Msg.caller()
    let blobCallerBytes = caller.bytes  # seq[byte]
    let blobCaller = blobCallerBytes.mapIt(uint8(it))  # seq[uint8]に変換
    
    # 統一処理の単純テスト: 単一blobを返す
    echo "Using asBlobValue() for unified processing:"
    let unifiedBlob = asBlobValue(blobCaller)  # 統一内部表現
    
    echo "Step 2: unified blob created successfully"
    icEcho "Unified blob kind: ", unifiedBlob.kind
    icEcho "Can convert to blob: ", unifiedBlob.canConvertToBlob()
    icEcho "Is vec nat8: ", unifiedBlob.isVecNat8()
    
    reply(unifiedBlob)
    
  except Exception as e:
    echo "Error in responseEcdsaStep2: ", e.msg
    reply("Error: " & e.msg)

proc responseEcdsaStep3() {.query.} =
  echo "===== ecdsa_args responseEcdsaStep3() ====="
  try:
    echo "Step 3: Creating key_id record with EcdsaCurve enum"
    
    var keyIdFields = initTable[string, CandidValue]()
    keyIdFields["curve"] = newCandidValue(EcdsaCurve.secp256k1)  # Enum → Variant
    keyIdFields["name"] = newCandidText("dfx_test_key")
    let keyIdRecord = newCandidRecord(keyIdFields)
    
    echo "Step 3: key_id record created successfully"
    icEcho "key_id record: ", keyIdRecord
    
    reply(keyIdRecord)
    
  except Exception as e:
    echo "Error in responseEcdsaStep3: ", e.msg
    reply("Error: " & e.msg)

proc responseEcdsaStep4() {.query.} =
  echo "===== ecdsa_args responseEcdsaStep4() ====="
  try:
    echo "Step 4: Creating complete ECDSA structure step by step"
    
    # Step 4.1: caller → blob
    let caller = Msg.caller()
    let blobCaller = caller.bytes.mapIt(uint8(it))
    let derivationPath = @[blobCaller]
    
    # Step 4.2: 各フィールドを個別に作成
    let canisterId = newCandidNull()
    let derivationCandid = newCandidValue(derivationPath)
    
    var keyIdFields = initTable[string, CandidValue]()
    keyIdFields["curve"] = newCandidValue(EcdsaCurve.secp256k1)
    keyIdFields["name"] = newCandidText("dfx_test_key")
    let keyIdRecord = newCandidRecord(keyIdFields)
    
    # Step 4.3: フィールドを段階的に追加
    var ecdsaFields = initTable[string, CandidValue]()
    ecdsaFields["canister_id"] = canisterId
    echo "Step 4.3a: canister_id added"
    
    ecdsaFields["derivation_path"] = derivationCandid
    echo "Step 4.3b: derivation_path added"
    
    ecdsaFields["key_id"] = keyIdRecord
    echo "Step 4.3c: key_id added"
    
    # Step 4.4: 最終Record作成
    let ecdsaArgs = newCandidRecord(ecdsaFields)
    echo "Step 4.4: Complete ECDSA record created"
    
    reply(ecdsaArgs)
    
  except Exception as e:
    echo "Error in responseEcdsaStep4: ", e.msg
    reply("Error: " & e.msg)

proc responseEcdsaFull() {.query.} =
  echo "===== ecdsa_args responseEcdsaFull() ====="
  try:
    echo "Step 3: Creating full ECDSA structure"
    
    # Principal.bytes取得
    let caller = Msg.caller()
    let blobCallerBytes = caller.bytes
    let blobCaller = blobCallerBytes.mapIt(uint8(it))
    
    # derivation_path作成
    let derivationPath = @[blobCaller]
    
    # ECDSA引数構造を作成
    var ecdsaFields = initTable[string, CandidValue]()
    ecdsaFields["canister_id"] = newCandidNull()  # opt principal - None
    ecdsaFields["derivation_path"] = newCandidValue(derivationPath)  # vec blob
    
    # key_id record作成
    var keyIdFields = initTable[string, CandidValue]()
    keyIdFields["curve"] = newCandidValue(EcdsaCurve.secp256k1)
    keyIdFields["name"] = newCandidText("dfx_test_key")
    let keyIdRecord = newCandidRecord(keyIdFields)
    ecdsaFields["key_id"] = keyIdRecord
    
    let ecdsaArgs = newCandidRecord(ecdsaFields)
    
    echo "Full ECDSA structure created successfully"
    icEcho "ECDSA Args kind: ", ecdsaArgs.kind
    
    reply("Full ECDSA structure successful")
    
  except Exception as e:
    echo "Error in responseEcdsaFull: ", e.msg
    reply("Error: " & e.msg)

# ================================================================================
# Vec Blob テスト関数群
# ================================================================================

proc responseVecBlobSimple() {.query.} =
  echo "===== ecdsa_args responseVecBlobSimple() ====="
  # シンプルなvec blob構造をテスト
  let vecBlob = @[
    @[0x41u8, 0x42u8],  # "AB"
    @[0x43u8, 0x44u8]   # "CD"
  ]
  icEcho "vec blob length: ", vecBlob.len
  icEcho "vec blob: ", vecBlob
  # seq[seq[uint8]]をCandidValueに変換してからreply
  let candidVecBlob = newCandidValue(vecBlob)
  reply(candidVecBlob)

proc responseVecBlobToRecord() {.query.} =
  echo "===== ecdsa_args responseVecBlobToRecord() ====="
  try:
    # derivation_pathとしてのvec blobをRecord内で使用
    echo "Step 1: Creating vec blob..."
    let derivationPath = @[
      @[0x01u8, 0x02u8],  # 最初のblob
      @[0x03u8, 0x04u8]   # 二番目のblob
    ]
    echo "Step 2: vec blob created"
    
    echo "Step 3: Creating record with vec blob..."
    var record = newCRecord()
    record["derivation_path"] = newCandidValue(derivationPath)
    echo "Step 4: Record with vec blob created"
    
    echo "Step 5: About to reply..."
    reply(record)
    echo "Step 6: Reply successful"
    
  except CatchableError as e:
    echo "Error in responseVecBlobToRecord: ", e.msg
    reply("Error: " & e.msg)

# ================================================================================
# その他の補助テスト関数
# ================================================================================

proc responseSimpleRecord() {.query.} =
  echo "===== ecdsa_args responseSimpleRecord() ====="
  try:
    echo "Step 1: Creating simple record structure"
    
    # シンプルなrecord構造の作成
    var simpleFields = initTable[string, CandidValue]()
    simpleFields["name"] = newCandidText("test")
    simpleFields["value"] = newCandidValue(42u32)
    let simpleRecord = newCandidRecord(simpleFields)
    
    echo "Simple record created successfully"
    icEcho "Simple record: ", simpleRecord
    
    reply(simpleRecord)
    
  except Exception as e:
    echo "Error in responseSimpleRecord: ", e.msg
    reply("Error: " & e.msg)

proc responseVecBlobTest() {.query.} =
  echo "===== ecdsa_args responseVecBlobTest() ====="
  try:
    echo "Step 1: Testing simple vec blob return"
    
    # 固定データでvec blob作成をテスト
    let fixedBlob = @[1u8, 2u8, 3u8, 4u8]
    let blobElement = CandidValue(kind: ctBlob, blobVal: fixedBlob)
    
    var vecElements = newSeq[CandidValue]()
    vecElements.add(blobElement)
    let vecBlobValue = CandidValue(kind: ctVec, vecVal: vecElements)
    
    echo "Vec blob created successfully"
    reply(vecBlobValue)
    
  except Exception as e:
    echo "Error in responseVecBlobTest: ", e.msg
    reply("Error: " & e.msg)

proc responseOptTest() {.query.} =
  echo "===== ecdsa_args responseOptTest() ====="
  try:
    echo "Step 1: Testing simple opt text return"
    
    # 最初にSimpleなSome値をテスト
    let textValue = newCandidText("test")
    let someOptValue = newCandidOpt(some(textValue))
    
    echo "Created some opt value successfully"
    icEcho "Opt value kind: ", someOptValue.kind
    icEcho "Opt value isSome: ", someOptValue.optVal.isSome()
    
    echo "About to reply with some opt value..."
    reply(someOptValue)
    echo "Reply completed successfully"
    
  except Exception as e:
    echo "Error in responseOptTest: ", e.msg
    echo "Error type: ", e.name
    reply("Error: " & e.msg)

proc responseOptNoneTest() {.query.} =
  echo "===== ecdsa_args responseOptNoneTest() ====="
  try:
    echo "Step 1: Testing opt none return"
    
    # None値のテスト
    echo "Creating none opt value..."
    let noneOptValue = newCandidNull()
    echo "Created none opt value successfully"
    
    icEcho "Opt value kind: ", noneOptValue.kind
    icEcho "Opt value isNone: ", noneOptValue.optVal.isNone()
    
    echo "About to reply with none opt value..."
    reply(noneOptValue)
    echo "Reply completed successfully"
    
  except Exception as e:
    echo "Error in responseOptNoneTest: ", e.msg
    echo "Error type: ", e.name
    reply("Error: " & e.msg)

proc responseEcdsaDebugFields() {.query.} =
  echo "===== ecdsa_args responseEcdsaDebugFields() ====="
  try:
    echo "Step 1: Testing each field individually"
    
    # 各フィールドを個別にテスト
    echo "Testing canister_id field..."
    let canisterId = newCandidNull()
    echo "canister_id created successfully"
    
    echo "Testing derivation_path field..."
    let caller = Msg.caller()
    let blobCaller = caller.bytes.mapIt(uint8(it))
    let derivationPath = @[blobCaller]
    let derivationCandid = newCandidValue(derivationPath)
    echo "derivation_path created successfully"
    
    echo "Testing key_id field..."
    var keyIdFields = initTable[string, CandidValue]()
    keyIdFields["curve"] = newCandidValue(EcdsaCurve.secp256k1)
    keyIdFields["name"] = newCandidText("dfx_test_key")
    let keyIdRecord = newCandidRecord(keyIdFields)
    echo "key_id created successfully"
    
    echo "All individual fields created successfully"
    reply("All fields OK individually")
    
  except Exception as e:
    echo "Error in responseEcdsaDebugFields: ", e.msg
    echo "Error type: ", e.name
    reply("Error: " & e.msg)

proc responseEcdsaDebugRecord() {.query.} =
  echo "===== ecdsa_args responseEcdsaDebugRecord() ====="
  try:
    echo "Step 1: Creating record with fields one by one"
    
    # 段階的にRecordを構築
    var ecdsaFields = initTable[string, CandidValue]()
    echo "Empty record created"
    
    echo "Adding canister_id field..."
    ecdsaFields["canister_id"] = newCandidNull()
    echo "canister_id field added"
    
    echo "Creating partial record..."
    let partialRecord = newCandidRecord(ecdsaFields)
    echo "Partial record created successfully"
    
    reply("Partial record creation successful")
    
  except Exception as e:
    echo "Error in responseEcdsaDebugRecord: ", e.msg
    echo "Error type: ", e.name
    reply("Error: " & e.msg)
