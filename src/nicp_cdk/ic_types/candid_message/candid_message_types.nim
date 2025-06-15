import std/options
import std/tables
import std/macros
import std/sequtils
import std/strutils
import std/algorithm
import ../candid_types


type 
  # ================================================================================
  # Candid Message Decoder/Encoder 共通型
  # ================================================================================
  
  # 型テーブルエントリを表す型
  TypeTableEntry* = ref object
    case kind*: CandidType
    of ctRecord:
      recordFields*: seq[tuple[hash: uint32, fieldType: int]]  # int は型テーブルインデックスまたは負の型コード
    of ctVariant:
      variantFields*: seq[tuple[hash: uint32, fieldType: int]]
    of ctOpt:
      optInnerType*: int
    of ctVec:
      vecElementType*: int
    of ctFunc:
      funcArgs*: seq[int]
      funcReturns*: seq[int]
      funcAnnotations*: seq[byte]
    of ctService:
      serviceMethods*: seq[tuple[hash: uint32, methodType: int]]
    else:
      discard

  # デコード結果を格納する型
  CandidDecodeResult* = object
    typeTable*: seq[TypeTableEntry]
    values*: seq[CandidValue]

  # 型テーブル構築用の型情報
  TypeDescriptor* = ref object
    case kind*: CandidType
    of ctRecord:
      recordFields*: seq[tuple[hash: uint32, fieldType: TypeDescriptor]]  # ハッシュ値を直接保持
    of ctVariant:
      variantFields*: seq[tuple[hash: uint32, fieldType: TypeDescriptor]]  # ハッシュ値を直接保持
    of ctOpt:
      optInnerType*: TypeDescriptor
    of ctVec:
      vecElementType*: TypeDescriptor
    of ctFunc:
      funcArgs*: seq[TypeDescriptor]
      funcReturns*: seq[TypeDescriptor]
      funcAnnotations*: seq[byte]
    of ctService:
      serviceMethods*: seq[tuple[hash: uint32, methodType: TypeDescriptor]]  # ハッシュ値を直接保持
    else:
      discard

  # 型テーブル構築時の作業用データ
  TypeBuilder* = object
    typeTable*: seq[TypeTableEntry]
    typeIndexMap*: Table[string, int]  # 型のハッシュ→インデックスのマップ

# デコードエラー
type CandidDecodeError* = object of CatchableError

