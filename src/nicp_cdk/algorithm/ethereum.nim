## Ethereum Signature Module
## 
## This module provides Ethereum-specific signature operations with 0x prefixes.
## It handles Ethereum address creation, signature verification with addresses,
## and EIP-compliant message hashing for Web3 applications.

import std/strutils
import std/sequtils
import nimcrypto/keccak
import secp256k1

type
  EcdsaVerificationError* = object of CatchableError
  SignatureFormatError* = object of CatchableError
  EthereumConversionError* = object of CatchableError


proc toEvmHexString*(data: seq[uint8], prefix: bool = true): string =
  ## Convert byte sequence to hex string with 0x prefix for Ethereum compatibility
  let hexStr = data.mapIt(it.toHex(2)).join("")
  if prefix:
    return "0x" & hexStr.toLowerAscii()
  else:
    return hexStr.toLowerAscii()


proc decompressPublicKey*(compressedKey: seq[uint8]): seq[uint8] =
  ## Decompress a compressed secp256k1 public key (33 bytes) to uncompressed format (65 bytes)
  if compressedKey.len != 33:
    raise newException(EthereumConversionError, "Compressed key must be 33 bytes")
  
  try:
    # Use secp256k1 library to parse and decompress the key
    let pubkeyResult = SkPublicKey.fromRaw(compressedKey)
    if pubkeyResult.isErr:
      raise newException(EthereumConversionError, "Failed to parse compressed public key")
    
    let pubkey = pubkeyResult.get()
    
    # Convert to uncompressed format (65 bytes)
    let uncompressedArray = pubkey.toRaw()
    
    # Convert array to seq
    var uncompressed = newSeq[uint8](65)
    for i in 0..<65:
      uncompressed[i] = uncompressedArray[i]
    
    return uncompressed
  except:
    raise newException(EthereumConversionError, "secp256k1 decompression failed")


proc keccak256Hash*(data: string): seq[uint8] =
  ## Hash string data using Keccak-256 with EIP-191 format
  ## This follows the Ethereum personal_sign standard: "\x19Ethereum Signed Message:\n" + length + message
  
  # EIP-191 personal_sign format
  let personalMessage = "\x19Ethereum Signed Message:\n" & $data.len & data
  
  var keccakCtx: keccak256
  keccakCtx.init()
  keccakCtx.update(personalMessage)
  let hash = keccakCtx.finish()
  
  result = newSeq[uint8](32)
  for i in 0..<32:
    result[i] = hash.data[i]


proc keccak256HashRaw*(data: string): seq[uint8] =
  ## Hash string data using Keccak-256 without EIP-191 format (raw hashing)
  
  var keccakCtx: keccak256
  keccakCtx.init()
  keccakCtx.update(data)
  let hash = keccakCtx.finish()
  
  result = newSeq[uint8](32)
  for i in 0..<32:
    result[i] = hash.data[i]


proc parseSignature*(signatureHex: string): tuple[r: seq[uint8], s: seq[uint8], v: uint8] =
  ## Parse signature hex string into r, s, v components
  let cleanSig = if signatureHex.startsWith("0x"): signatureHex[2..^1] else: signatureHex
  
  if cleanSig.len != 128 and cleanSig.len != 130:
    raise newException(SignatureFormatError, "Invalid signature length")
  
  var r = newSeq[uint8](32)
  var s = newSeq[uint8](32)
  var v: uint8
  
  # Parse r (first 32 bytes)
  for i in 0..<32:
    let byteStr = cleanSig[i*2..<i*2+2]
    r[i] = parseHexInt(byteStr).uint8
  
  # Parse s (next 32 bytes)
  for i in 0..<32:
    let byteStr = cleanSig[64+i*2..<64+i*2+2]
    s[i] = parseHexInt(byteStr).uint8
  
  # Parse v (last byte if present)
  if cleanSig.len == 130:
    let vStr = cleanSig[128..<130]
    v = parseHexInt(vStr).uint8
  else:
    v = 27  # Default recovery ID
  
  return (r: r, s: s, v: v)


proc recoverPublicKeyFromSignature*(
  messageHash: seq[uint8],
  signatureHex: string,
  recoveryId: uint8
): seq[uint8] =
  ## Recover public key from signature using secp256k1
  
  try:
    # Parse signature
    let (r, s, _) = parseSignature(signatureHex)
    
    # Create recoverable signature bytes (65 bytes: r + s + recoveryId)
    var recoverableSignatureBytes = newSeq[uint8](65)
    for i in 0..<32:
      recoverableSignatureBytes[i] = r[i]
    for i in 0..<32:
      recoverableSignatureBytes[i+32] = s[i]
    recoverableSignatureBytes[64] = recoveryId
    
    # Create secp256k1 recoverable signature object
    let recoverableSigResult = SkRecoverableSignature.fromRaw(recoverableSignatureBytes)
    if recoverableSigResult.isErr:
      raise newException(EcdsaVerificationError, "Invalid recoverable signature")
    
    let recoverableSig = recoverableSigResult.get()
    
    # Recover public key
    var messageArray: array[32, byte]
    for i in 0..<32:
      messageArray[i] = messageHash[i].byte
    let message = SkMessage(messageArray)
    
    let pubkeyResult = recoverableSig.recover(message)
    if pubkeyResult.isErr:
      raise newException(EcdsaVerificationError, "Failed to recover public key")
    
    let pubkey = pubkeyResult.get()
    let uncompressedArray = pubkey.toRaw()
    
    # Convert to seq[uint8]
    var result = newSeq[uint8](65)
    for i in 0..<65:
      result[i] = uncompressedArray[i]
    
    return result
    
  except Exception as e:
    raise newException(EcdsaVerificationError, "Recovery failed: " & e.msg)


proc publicKeyToEthereumAddress*(pubKey: seq[uint8]): string =
  ## Convert public key (65 bytes uncompressed) to Ethereum address
  if pubKey.len != 65 or pubKey[0] != 0x04:
    raise newException(EcdsaVerificationError, "Invalid uncompressed key format")
  
  # Remove 0x04 prefix to get 64-byte coordinate data
  let coordinateData = pubKey[1..^1]
  
  # Keccak-256 hash the coordinate data
  var keccakCtx: keccak256
  keccakCtx.init()
  keccakCtx.update(coordinateData)
  let hash = keccakCtx.finish()
  
  # Take the last 20 bytes as Ethereum address
  let addressBytes = hash.data[12..^1]
  
  # Convert to hex string with 0x prefix
  return toEvmHexString(addressBytes, true)


proc icpPublicKeyToEvmAddress*(icpPublicKey: seq[uint8]): string =
  ## Convert ICP ECDSA public key (33 bytes compressed format) to Ethereum address
  if icpPublicKey.len != 33:
    raise newException(EthereumConversionError, "ICP public key must be 33 bytes (compressed format)")
  
  # Decompress the compressed key to uncompressed format
  let uncompressedKey = decompressPublicKey(icpPublicKey)
  
  # Convert to Ethereum address using the uncompressed key
  return publicKeyToEthereumAddress(uncompressedKey)


proc verifyEthereumSignatureWithAddress*(
  ethereumAddress: string,
  message: string,
  signatureHex: string
): bool =
  ## Verify Ethereum signature using address (without needing the public key)
  ## Uses EIP-191 format for message hashing by default
  
  try:
    # Hash the message using Keccak-256 with EIP-191 format
    let messageHash = keccak256Hash(message)
    
    # Try recovery with different recovery IDs (0 and 1)
    for recoveryId in [0'u8, 1]:
      try:
        # Recover public key from signature
        let recoveredPubKey = recoverPublicKeyFromSignature(messageHash, signatureHex, recoveryId)
        
        # Convert recovered public key to Ethereum address
        let recoveredAddress = publicKeyToEthereumAddress(recoveredPubKey)
        
        # Compare addresses (case-insensitive)
        if recoveredAddress.toLowerAscii() == ethereumAddress.toLowerAscii():
          return true
      except:
        continue
    
    return false
    
  except Exception as e:
    echo "Verification error: ", e.msg
    return false


proc verifyPersonalMessageWithAddress*(
  ethereumAddress: string,
  message: string,
  signatureHex: string
): bool =
  ## Verify Ethereum personal_sign message using address
  ## This function is now equivalent to verifyEthereumSignatureWithAddress
  
  # Use the standard EIP-191 format hashing
  let messageHash = keccak256Hash(message)
  
  # Try recovery with different recovery IDs
  for recoveryId in [0'u8, 1]:
    try:
      let recoveredPubKey = recoverPublicKeyFromSignature(messageHash, signatureHex, recoveryId)
      let recoveredAddress = publicKeyToEthereumAddress(recoveredPubKey)
      
      if recoveredAddress.toLowerAscii() == ethereumAddress.toLowerAscii():
        return true
    except:
      continue
  
  return false


proc verifyStructuredMessageWithAddress*(
  ethereumAddress: string,
  domain: string,
  message: string,
  signatureHex: string
): bool =
  ## Verify structured message (EIP-712 style) using address
  
  # Create structured message hash using raw hashing
  let structuredMessage = domain & message
  let messageHash = keccak256HashRaw(structuredMessage)
  
  # Try recovery with different recovery IDs
  for recoveryId in [0'u8, 1]:
    try:
      let recoveredPubKey = recoverPublicKeyFromSignature(messageHash, signatureHex, recoveryId)
      let recoveredAddress = publicKeyToEthereumAddress(recoveredPubKey)
      
      if recoveredAddress.toLowerAscii() == ethereumAddress.toLowerAscii():
        return true
    except:
      continue
  
  return false


proc verifyMultipleSignatures*(
  verifications: seq[tuple[address: string, message: string, signature: string]]
): seq[bool] =
  ## Verify multiple signatures efficiently
  
  result = newSeq[bool](verifications.len)
  
  for i, verification in verifications:
    result[i] = verifyEthereumSignatureWithAddress(
      verification.address, 
      verification.message, 
      verification.signature
    )


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
