import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode
import ../../src/nicp_cdk/ic_types/ic_principal

suite "ic_service tests":
  test "newCandidService creates correct CandidValue":
    let principal = Principal.fromText("aaaaa-aa")
    let serviceValue = newCandidService(principal)
    check serviceValue.kind == ctService
    check serviceValue.serviceVal == principal

  test "encode and decode service message":
    let principal = Principal.fromText("r7inp-6aaaa-aaaaa-aaabq-cai")
    let serviceValue = newCandidService(principal)
    let encoded = encodeCandidMessage(@[serviceValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctService
    check decoded.values[0].serviceVal == principal

  test "encode and decode another service message":
    let principal = Principal.fromText("2vxsx-fae")
    let serviceValue = newCandidService(principal)
    let encoded = encodeCandidMessage(@[serviceValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctService
    check decoded.values[0].serviceVal == principal 