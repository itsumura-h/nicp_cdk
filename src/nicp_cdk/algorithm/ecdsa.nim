## ECDSA Signature Verification Module
## 
## This module provides pure ECDSA cryptographic operations using secp256k1.
## It handles raw byte operations without 0x prefixes for low-level cryptographic processing.
## For Ethereum-specific operations with 0x prefixes, use the ethereum.nim module.

import nimcrypto/keccak
import secp256k1
import ./hex_bytes
import ../ic_api

type
  EcdsaError* = object of ValueError


func keccak256Hash*(message: string): seq[uint8] =
  ## Calculate Keccak-256 hash of message
  var keccakCtx: keccak256
  keccakCtx.init()
  keccakCtx.update(message)
  let hash = keccakCtx.finish()
  
  # Convert array to seq properly
  result = newSeq[uint8](32)
  for i in 0..<32:
    result[i] = hash.data[i]


proc validateSignatureWithSecp256k1*(
  messageHash: seq[uint8],
  signatureBytes: seq[uint8], 
  publicKeyBytes: seq[uint8]
): bool =
  ## Validate signature using secp256k1 library
  ## This function encapsulates direct secp256k1 calls for signature validation
  try:
    let sigResult = SkSignature.fromHex(signatureBytes.toHexString())
    let msgResult = SkMessage.fromBytes(messageHash)
    let pubKeyResult = SkPublicKey.fromRaw(publicKeyBytes)
    
    # Check if all parsing succeeded
    if sigResult.isErr or msgResult.isErr or pubKeyResult.isErr:
      devEcho "Error parsing signature components:"
      if sigResult.isErr:
        devEcho "  Signature error: ", sigResult.error
      if msgResult.isErr:
        devEcho "  Message error: ", msgResult.error
      if pubKeyResult.isErr:
        devEcho "  Public key error: ", pubKeyResult.error
      return false
    
    # Verify signature
    let isValid = secp256k1.verify(
      sigResult.get(),
      msgResult.get(),
      pubKeyResult.get()
    )
    devEcho "Signature validation result: ", isValid
    return isValid
    
  except Exception as e:
    devEcho "Exception in validateSignatureWithSecp256k1: ", e.msg
    return false


proc verifySignatureWithSecp256k1*(
  message: string,
  signatureHex: string,
  publicKeyHex: string
): bool =
  ## Verify signature using secp256k1 library with hex inputs
  ## This function encapsulates direct secp256k1 calls for signature verification
  try:
    let messageHash = keccak256Hash(message)
    let sigResult = SkSignature.fromHex(signatureHex)
    let msgResult = SkMessage.fromBytes(messageHash)
    let pubKeyResult = SkPublicKey.fromRaw(hexToBytes(publicKeyHex))

    if sigResult.isErr or msgResult.isErr or pubKeyResult.isErr:
      devEcho "Error parsing components for verification:"
      if sigResult.isErr:
        devEcho "  Signature error: ", sigResult.error
      if msgResult.isErr:
        devEcho "  Message error: ", msgResult.error
      if pubKeyResult.isErr:
        devEcho "  Public key error: ", pubKeyResult.error
      return false

    let isValid = secp256k1.verify(
      sigResult.get(),
      msgResult.get(),
      pubKeyResult.get()
    )
    devEcho "Signature verification result: ", isValid
    return isValid

  except Exception as e:
    devEcho "Exception in verifySignatureWithSecp256k1: ", e.msg
    return false
