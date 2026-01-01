discard """
  cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/test_sign_verify.nim

import unittest
import secp256k1
import nimcrypto/keccak

proc rng(data: var openArray[byte]):bool =
  data[0] += 1
  true

suite("sign and verify"):
  test("secp256k1 raw bytes"):
    let secretKey = SkSecretKey.random(rng)[]
    let publicKey = secretKey.toPublicKey()
    echo "publicKey: ", publicKey
    let message = "Hello, World!"
    var keccak: keccak256
    keccak.init()
    keccak.update(message)
    let messageHash = keccak.finish()
    echo "messageHash: ", messageHash.data
    let skMessage = SkMessage.fromBytes(messageHash.data).get()
    let signature = sign(secretKey, skMessage)
    echo "signature: ", signature
    let verifyResult = verify(signature, skMessage, publicKey)
    echo "verifyResult: ", verifyResult
    check verifyResult
