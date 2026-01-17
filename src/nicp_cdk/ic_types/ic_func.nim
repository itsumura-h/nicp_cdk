import std/options
import ./ic_principal
import ./candid_types


type FuncType* = enum
  Query = "query"
  Update = "update"
  CompositeQuery = "composite_query"
  Oneway = "oneway"

proc `$`*(funcType: FuncType): string =
  ## Convert FuncType to string
  case funcType
  of Query: "query"
  of Update: "update"
  of CompositeQuery: "composite_query"
  of Oneway: "oneway"

proc parseFunc*(s: string): FuncType =
  ## Parse string to FuncType
  case s
  of "query": Query
  of "update": Update
  of "composite_query": CompositeQuery
  of "oneway": Oneway
  else: raise newException(ValueError, "Invalid FuncType: " & s)


# Query annotation を持つ func 参照を作成（CandidType 指定版）
proc new*(
  _: type IcFunc,
  principal: Principal,
  funcType: FuncType,
  methodName: string,
  args: seq[CandidType] = @[],
  returns = none(CandidType),
  argsDesc: seq[CandidTypeDesc] = @[],
  returnsDesc: Option[CandidTypeDesc] = none(CandidTypeDesc)
): IcFunc =
  result = new(IcFunc)
  result.principal = principal
  result.methodName = methodName
  result.args = args
  result.returns = returns
  result.annotations = @[$funcType]
  result.argsDesc = argsDesc
  result.returnsDesc = returnsDesc


proc isQuery*(f: IcFunc): bool =
  "query" in f.annotations

proc isOneway*(f: IcFunc): bool =
  "oneway" in f.annotations

# =============================================================
# Self principal helper and overload without principal argument
# =============================================================

proc new*(
  _: type IcFunc,
  funcType: FuncType,
  methodName: string,
  args: seq[CandidType] = @[],
  returnType = none(CandidType),
  argsDesc: seq[CandidTypeDesc] = @[],
  returnsDesc: Option[CandidTypeDesc] = none(CandidTypeDesc)
): IcFunc =
  ## Create a query func reference on the current canister
  let self = Principal.self()
  result = IcFunc.new(self, funcType, methodName, args, returnType, argsDesc, returnsDesc)
