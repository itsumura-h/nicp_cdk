# Candid型定義
# https://github.com/dfinity/candid/blob/master/spec/Candid.md#types
#[

T(null)      = sleb128(-1)  = 0x7f
T(bool)      = sleb128(-2)  = 0x7e
T(nat)       = sleb128(-3)  = 0x7d
T(int)       = sleb128(-4)  = 0x7c
T(nat8)      = sleb128(-5)  = 0x7b
T(nat16)     = sleb128(-6)  = 0x7a
T(nat32)     = sleb128(-7)  = 0x79
T(nat64)     = sleb128(-8)  = 0x78
T(int8)      = sleb128(-9)  = 0x77
T(int16)     = sleb128(-10) = 0x76
T(int32)     = sleb128(-11) = 0x75
T(int64)     = sleb128(-12) = 0x74
T(float32)   = sleb128(-13) = 0x73
T(float64)   = sleb128(-14) = 0x72
T(text)      = sleb128(-15) = 0x71
T(reserved)  = sleb128(-16) = 0x70
T(empty)     = sleb128(-17) = 0x6f
T(principal) = sleb128(-24) = 0x68

T(opt <datatype>) = sleb128(-18) I(<datatype>)              // 0x6e
T(vec <datatype>) = sleb128(-19) I(<datatype>)              // 0x6d
T(record {<fieldtype>^N}) = sleb128(-20) T*(<fieldtype>^N)  // 0x6c
T(variant {<fieldtype>^N}) = sleb128(-21) T*(<fieldtype>^N) // 0x6b

T : <fieldtype> -> i8*
T(<nat>:<datatype>) = leb128(<nat>) I(<datatype>)

T : <reftype> -> i8*
T(func (<datatype1>*) -> (<datatype2>*) <funcann>*) =
  sleb128(-22) T*(<datatype1>*) T*(<datatype2>*) T*(<funcann>*) // 0x6a
T(service {<methtype>*}) =
  sleb128(-23) T*(<methtype>*)                                    // 0x69

T : <methtype> -> i8*
T(<name>:<datatype>) = leb128(|utf8(<name>)|) i8*(utf8(<name>)) I(<datatype>)

T : <funcann> -> i8
T(query)  = i8(1)
T(oneway) = i8(2)
T(composite_query) = i8(3)

T* : <X>* -> i8*
T*(<X>^N) = leb128(N) T(<X>)^N
]#

const
  magicHeader*  = @[0x44'u8, 0x49'u8, 0x44'u8, 0x4C'u8]  # "DIDL"
  tagNull*      = 0x7f'u8  # null
  tagBool*      = 0x7e'u8  # bool
  tagNat*       = 0x7d'u8  # nat
  tagInt*       = 0x7c'u8  # int
  tagNat8*      = 0x7b'u8  # nat8
  tagNat16*     = 0x7a'u8  # nat16
  tagNat32*     = 0x79'u8  # nat32
  tagNat64*     = 0x78'u8  # nat64
  tagInt8*      = 0x77'u8  # int8
  tagInt16*     = 0x76'u8  # int16
  tagInt32*     = 0x75'u8  # int32
  tagInt64*     = 0x74'u8  # int64
  tagFloat32*   = 0x73'u8  # float32
  tagFloat64*   = 0x72'u8  # float64
  tagText*      = 0x71'u8  # text
  tagReserved*  = 0x70'u8  # reserved
  tagEmpty*     = 0x6f'u8  # empty
  tagOptional*  = 0x6e'u8  # optional
  tagVec*       = 0x6d'u8  # vec
  tagRecord*    = 0x6c'u8  # record
  tagVariant*   = 0x6b'u8  # variant
  tagPrincipal* = 0x68'u8  # principal
  tagFunc*      = 0x6a'u8  # func
  tagService*   = 0x69'u8  # service
  tagQuery*     = 0x01'u8  # query
  tagOneway*    = 0x02'u8  # oneway
  tagCompositeQuery* = 0x03'u8  # composite_query
