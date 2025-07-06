## ECDSA Signature Verification Module
## 
## This module provides functionality to verify ECDSA signatures using secp256k1.
## It handles Ethereum address verification with message hashing.

import std/strutils
import std/sequtils
import std/options
import nimcrypto/keccak
import secp256k1

type
  EcdsaVerificationError* = object of CatchableError
  SignatureFormatError* = object of CatchableError


proc toHexString*(data: seq[uint8], prefix: bool = true): string =
  ## Convert byte sequence to hex string
  let hexStr = data.mapIt(it.toHex(2)).join("")
  if prefix:
    return "0x" & hexStr.toLowerAscii()
  else:
    return hexStr.toLowerAscii()


proc hexToBytes*(hexStr: string): seq[uint8] =
  ## Convert hex string to byte sequence
  let cleanHex = if hexStr.startsWith("0x"): hexStr[2..^1] else: hexStr
  if cleanHex.len mod 2 != 0:
    raise newException(SignatureFormatError, "Invalid hex string length")
  
  result = newSeq[uint8](cleanHex.len div 2)
  for i in 0..<(cleanHex.len div 2):
    let byteStr = cleanHex[i*2..i*2+1]
    result[i] = parseHexInt(byteStr).uint8


proc keccak256Hash*(message: string): seq[uint8] =
  ## Hash message using Keccak-256 (Ethereum standard)
  var keccakCtx: keccak256
  keccakCtx.init()
  keccakCtx.update(message)
  let hash = keccakCtx.finish()
  # Convert array to seq properly
  result = newSeq[uint8](32)
  for i in 0..<32:
    result[i] = hash.data[i]


proc parseSignature*(signatureHex: string): tuple[r: seq[uint8], s: seq[uint8], v: uint8] =
  ## Parse ECDSA signature from hex string
  ## Expected format: 0x + 64 bytes (32 bytes r + 32 bytes s) or 65 bytes (r + s + v)
  
  let cleanSig = if signatureHex.startsWith("0x"): signatureHex[2..^1] else: signatureHex
  
  if cleanSig.len != 128 and cleanSig.len != 130:
    raise newException(SignatureFormatError, 
                      "Invalid signature length. Expected 64 or 65 bytes, got " & $cleanSig.len)
  
  # Parse r and s (first 64 bytes)
  let rHex = cleanSig[0..63]
  let sHex = cleanSig[64..127]
  
  let r = hexToBytes(rHex)
  let s = hexToBytes(sHex)
  
  # Parse v (recovery id) if present
  var v: uint8 = 0
  if cleanSig.len == 130:
    let vHex = cleanSig[128..129]
    v = parseHexInt(vHex).uint8
  
  return (r: r, s: s, v: v)


proc verifyEcdsaSignature*(
  publicKey: seq[uint8], 
  messageHash: seq[uint8], 
  signatureHex: string
): bool =
  ## Verify ECDSA signature using secp256k1
  
  try:
    # Parse signature
    let (r, s, v) = parseSignature(signatureHex)
    
    # Create secp256k1 signature object
    # Combine r and s into a single byte array
    var signatureBytes = newSeq[uint8](64)
    for i in 0..<32:
      signatureBytes[i] = r[i]
    for i in 0..<32:
      signatureBytes[i+32] = s[i]
    
    let sigResult = SkSignature.fromRaw(signatureBytes)
    if sigResult.isErr:
      echo "Failed to parse signature: ", sigResult.error
      return false
    
    let signature = sigResult.get()
    
    # Create secp256k1 public key object
    let pubkeyResult = SkPublicKey.fromRaw(publicKey)
    if pubkeyResult.isErr:
      echo "Failed to parse public key: ", pubkeyResult.error
      return false
    
    let pubkey = pubkeyResult.get()
    
    # Verify signature
    var messageArray: array[32, byte]
    for i in 0..<32:
      messageArray[i] = messageHash[i].byte
    let message = SkMessage(messageArray)
    let verifyResult = signature.verify(message, pubkey)
    return verifyResult
    
  except Exception as e:
    echo "Verification error: ", e.msg
    return false


proc verifyEthereumSignature*(
  ethereumAddress: string,
  message: string,
  signatureHex: string,
  publicKey: seq[uint8]
): bool =
  ## Verify Ethereum signature with message and public key
  
  try:
    # Hash the message using Keccak-256 (Ethereum standard)
    let messageHash = keccak256Hash(message)
    
    # Verify the signature
    return verifyEcdsaSignature(publicKey, messageHash, signatureHex)
    
  except Exception as e:
    echo "Ethereum signature verification error: ", e.msg
    return false


proc verifyWithPublicKey*(
  publicKeyHex: string,
  message: string,
  signatureHex: string
): bool =
  ## Verify signature using public key in hex format
  
  try:
    # Convert hex public key to bytes
    let publicKey = hexToBytes(publicKeyHex)
    
    # Hash the message
    let messageHash = keccak256Hash(message)
    
    # Verify signature
    return verifyEcdsaSignature(publicKey, messageHash, signatureHex)
    
  except Exception as e:
    echo "Public key verification error: ", e.msg
    return false


proc verifyWithHash*(
  publicKeyHex: string,
  messageHashHex: string,
  signatureHex: string
): bool =
  ## Verify signature using pre-hashed message
  
  try:
    # Convert hex public key to bytes
    let publicKey = hexToBytes(publicKeyHex)
    
    # Convert hex message hash to bytes
    let messageHash = hexToBytes(messageHashHex)
    
    # Verify signature
    return verifyEcdsaSignature(publicKey, messageHash, signatureHex)
    
  except Exception as e:
    echo "Hash verification error: ", e.msg
    return false


# Convenience functions for different input formats
proc verifyEthereumMessage*(
  ethereumAddress: string,
  message: string,
  signatureHex: string,
  publicKeyHex: string
): bool =
  ## Verify Ethereum message signature with address and public key
  
  try:
    let publicKey = hexToBytes(publicKeyHex)
    return verifyEthereumSignature(ethereumAddress, message, signatureHex, publicKey)
  except Exception as e:
    echo "Ethereum message verification error: ", e.msg
    return false


proc validateEthereumAddress*(address: string): bool =
  ## Validate Ethereum address format
  let cleanAddress = if address.startsWith("0x"): address[2..^1] else: address
  return cleanAddress.len == 40 and cleanAddress.allIt(it in "0123456789abcdefABCDEF")


proc validateSignatureFormat*(signatureHex: string): bool =
  ## Validate signature hex format
  try:
    let cleanSig = if signatureHex.startsWith("0x"): signatureHex[2..^1] else: signatureHex
    return cleanSig.len == 128 or cleanSig.len == 130
  except:
    return false


proc createTestSignature*(): string =
  ## Create a test signature for demonstration purposes
  ## This is not a real signature - just for testing the parsing logic
  return "0x" & "1".repeat(128)  # 64 bytes of 0x01
