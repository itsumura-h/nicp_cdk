discard """
  cmd : "nim c --skipUserCfg $file"
"""

# nim c -r --skipUserCfg tests/types/test_empty.nim

import unittest
import ../../src/nicp_cdk/ic_types/candid_types
import ../../src/nicp_cdk/ic_types/candid_message/candid_encode
import ../../src/nicp_cdk/ic_types/candid_message/candid_decode


proc newCandidEmpty*(): CandidValue =
  ## Creates a CandidValue of kind ctEmpty. (Temporary definition for testing)
  CandidValue(kind: ctEmpty)

suite "ic_empty tests":
  test "newCandidEmpty creates correct CandidValue":
    let emptyValue = newCandidEmpty()
    check emptyValue.kind == ctEmpty

  test "encode empty message":
    let emptyValue = newCandidEmpty()
    let encoded = encodeCandidMessage(@[emptyValue])
    # DIDL0ヘッダー(4バイト) + 型テーブル(3バイト) = 7バイト
    check encoded.len == 7

  test "encode and decode empty message":
    let emptyValue = newCandidEmpty()
    let encoded = encodeCandidMessage(@[emptyValue])
    let decoded = decodeCandidMessage(encoded)
    check decoded.values.len == 1
    check decoded.values[0].kind == ctEmpty 