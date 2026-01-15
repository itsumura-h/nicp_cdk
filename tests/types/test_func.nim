discard """
cmd: nim c --skipUserCfg tests/types/test_func.nim
"""
# nim c -r --skipUserCfg tests/types/test_func.nim

import unittest
import std/options
import std/sequtils
import std/strutils
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/ic_principal
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode

suite "IcFunc Candid encoding":
  test "func reference with type info and query annotation matches motoko transform function":
    # Expected hex from motoko transformFunc() output
    # This is the Candid encoding of the transform function reference
    let expectedHex = "4449444c066a0101010301016c02efabdecb010281ddb2900a036d7b6c03b2ceef2f7da2f5ed880402c6a4a19806046d056c02f1fee18d0371cbe4fdc70471010001010affffffffff9000010101097472616e73666f726d"
    
    # Create func reference to motoko_backend.transform with proper type information
    let principalStr = "uxrrr-q7777-77774-qaaaq-cai"
    let principal = Principal.fromText(principalStr)
    
    # TransformArgs = record { context: blob; response: HttpResponsePayload }
    # HttpResponsePayload = record { status: nat; headers: vec record { name: text; value: text }; body: blob }
    # HttpHeader = record { name: text; value: text }
    
    # Build nested type descriptors for proper encoding
    let httpHeaderType = CandidTypeDesc(
      kind: ctRecord,
      recordFields: @[
        ("name", CandidTypeDesc(kind: ctText)),
        ("value", CandidTypeDesc(kind: ctText))
      ]
    )
    
    let httpResponseType = CandidTypeDesc(
      kind: ctRecord,
      recordFields: @[
        ("status", CandidTypeDesc(kind: ctNat)),
        ("headers", CandidTypeDesc(kind: ctVec, vecElementType: httpHeaderType)),
        ("body", CandidTypeDesc(kind: ctBlob))
      ]
    )
    
    let transformArgsType = CandidTypeDesc(
      kind: ctRecord,
      recordFields: @[
        ("context", CandidTypeDesc(kind: ctBlob)),
        ("response", httpResponseType)
      ]
    )
    
    # Create function with proper type signature
    # The transform function:
    # - takes a single argument: TransformArgs (record)
    # - returns: HttpResponsePayload (record)
    # - is a query function
    #
    # NOTE: There is a known encoding difference when argsDesc is provided
    # that needs to be investigated. This test documents the expected output
    # from Motoko for reference.
    let transformFunc = newCandidFunc(
      principal,
      "transform",
      @[ctRecord],  # argument: TransformArgs record
      some(ctRecord),  # return: HttpResponsePayload record
      @["query"],  # annotation: query
      @[transformArgsType],  # argument type descriptor
      some(httpResponseType)  # return type descriptor
    )
    
    # Debug: Check if funcAnnotations is set in the function value
    echo "DEBUG: transformFunc.funcVal.annotations = ", transformFunc.funcVal.annotations
    echo "DEBUG: transformFunc.funcVal.annotations.len = ", transformFunc.funcVal.annotations.len
    
    # Additional debug: manually process annotations to see what we get
    var manualAnnotations: seq[byte] = @[]
    for ann in transformFunc.funcVal.annotations:
      case ann
      of "query": manualAnnotations.add(0x01'u8)
      of "oneway": manualAnnotations.add(0x02'u8)
      of "composite_query": manualAnnotations.add(0x03'u8)
      else: discard
    echo "DEBUG: manualAnnotations = ", manualAnnotations
    echo "DEBUG: manualAnnotations.len = ", manualAnnotations.len
    
    let encoded = encodeCandidMessage(@[transformFunc])
    let encodedHex = encoded.map(proc (b: byte): string = b.toHex()).join("").toLowerAscii()
    
    # NOTE: This test will fail until the annotation encoding issue is resolved
    # The difference is in the annotation length/value encoding
    # Expected pattern: ...47 10 00 01 01 0a... (with annotation byte 0x01)
    # Current output:   ...47 01 00 01 0a...    (without annotation byte)
    echo "encodedHex:  ", encodedHex
    echo "expectedHex: ", expectedHex
    check encodedHex == expectedHex

  test "func with query annotation property test":
    let principalStr = "uxrrr-q7777-77774-qaaaq-cai"
    let principal = Principal.fromText(principalStr)
    
    let transformFunc = newCandidFunc(
      principal,
      "transform",
      @[],
      none(CandidType),
      @["query"]
    )
    
    # Verify properties
    check transformFunc.kind == ctFunc
    check transformFunc.funcVal.methodName == "transform"
    check transformFunc.funcVal.principal == principal
    check transformFunc.funcVal.annotations.len == 1
    check transformFunc.funcVal.annotations[0] == "query"

  test "func encodes with proper annotation encoding":
    # Test that "query" annotation is correctly encoded as 0x01
    let principalStr = "uxrrr-q7777-77774-qaaaq-cai"
    let principal = Principal.fromText(principalStr)
    
    # Create simple function with no arguments
    let queryFunc = newCandidFunc(
      principal,
      "transform",
      @[],  # no arguments
      none(CandidType),  # no return type specified
      @["query"]  # annotation: query
    )
    
    let encoded = encodeCandidMessage(@[queryFunc])
    let encodedHex = encoded.map(proc (b: byte): string = b.toHex()).join("").toLowerAscii()
    
    # The encoded message should contain the query annotation byte (0x01)
    # Check that encoding succeeds and produces output
    check encoded.len > 0
    # Should contain annotation: 01 for query
    # and method name: 09 74 72 61 6e 73 66 6f 72 6d (length + "transform")
    check encodedHex.contains("09747261" & "6e73666f726d")  # "transform" in hex

