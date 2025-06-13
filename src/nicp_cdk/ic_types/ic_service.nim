import ./candid_types
import ./candid_funcs

# Service型の定義
type Service* = object

# Service型のコンストラクタ関数
proc new*(_: type Service, principal: string): CandidRecord =
  ## Principal IDからService型のCandidRecordを生成
  newCService(principal) 