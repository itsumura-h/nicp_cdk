import std/tables
import ../candid_types


type 
  # ================================================================================
  # Common types for Candid Message Decoder/Encoder
  # ================================================================================
  
  # Type representing a type table entry
  TypeTableEntry* = ref object
    case kind*: CandidType
    of ctRecord:
      recordFields*: seq[tuple[hash: uint32, fieldType: int]]  # int is a type table index or a negative type code
    of ctVariant:
      variantFields*: seq[tuple[hash: uint32, fieldType: int]]
    of ctOpt:
      optInnerType*: int
    of ctVec:
      vecElementType*: int
    of ctBlob:
      discard  # Blob is processed like Vec, but type info is different
    of ctFunc:
      funcArgs*: seq[int]
      funcReturns*: seq[int]
      funcAnnotations*: seq[byte]
    of ctService:
      serviceMethods*: seq[tuple[hash: uint32, methodType: int]]
    else:
      discard

  # Type to store decoding results
  CandidDecodeResult* = object
    typeTable*: seq[TypeTableEntry]
    values*: seq[CandidValue]

  # Type information for type table construction
  TypeDescriptor* = ref object
    case kind*: CandidType
    of ctRecord:
      recordFields*: seq[tuple[hash: uint32, fieldType: TypeDescriptor]]  # Directly holds hash values
    of ctVariant:
      variantFields*: seq[tuple[hash: uint32, fieldType: TypeDescriptor]]  # Directly holds hash values
    of ctOpt:
      optInnerType*: TypeDescriptor
    of ctVec:
      vecElementType*: TypeDescriptor
    of ctBlob:
      discard  # Blob is processed like Vec, but type info is different
    of ctFunc:
      funcArgs*: seq[TypeDescriptor]
      funcReturns*: seq[TypeDescriptor]
      funcAnnotations*: seq[byte]
    of ctService:
      serviceMethods*: seq[tuple[hash: uint32, methodType: TypeDescriptor]]  # Directly holds hash values
    else:
      discard

  # Working data for type table construction
  TypeBuilder* = object
    typeTable*: seq[TypeTableEntry]
    typeIndexMap*: Table[string, int]  # Map from type hash to index

# Decoding error
type CandidDecodeError* = object of CatchableError


proc `$`*(entry: TypeTableEntry): string =
  ## Converts TypeTableEntry to a string
  result = $entry.kind
