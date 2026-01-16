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


func keccak256Hash*(data: string): seq[uint8] =
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


proc convertIcpSignatureToEthereum*(
  icpSignature: seq[uint8],
  messageHash: seq[uint8],
  publicKey: seq[uint8]
): string =
  ## Convert ICP Management Canister signature (64 bytes, r+s) to Ethereum format (65 bytes, r+s+v)
  ## This function determines the correct recovery ID (v) and returns the full Ethereum signature
  
  if icpSignature.len != 64:
    raise newException(SignatureFormatError, "ICP signature must be 64 bytes")
  
  # Parse r and s from ICP signature
  let r = icpSignature[0..<32]
  let s = icpSignature[32..<64]
  
  # Try recovery IDs 0 and 1 (will be converted to v=27/28 for Ethereum)
  for rawRecoveryId in [0'u8, 1]:
    try:
      # Create Ethereum format signature for testing (r + s + v)
      let vValue = 27 + rawRecoveryId  # Ethereum v value (27 or 28)
      var testSignature = newSeq[uint8](65)
      for i in 0..<32:
        testSignature[i] = r[i]
      for i in 0..<32:
        testSignature[i+32] = s[i]
      testSignature[64] = vValue
      
      # Try to recover public key using this recovery ID (0 or 1, not 27/28)
      let recoveredPubKey = recoverPublicKeyFromSignature(
        messageHash, 
        toEvmHexString(testSignature[0..<64], false), # Only r+s for recovery
        rawRecoveryId  # Use 0 or 1, not 27/28
      )
      
      # Check if recovered public key matches the expected one
      if recoveredPubKey.len == 65 and publicKey.len == 33:
        # Decompress the ICP public key for comparison
        let decompressedIcpKey = decompressPublicKey(publicKey)
        if recoveredPubKey == decompressedIcpKey:
          # Found correct recovery ID, return Ethereum format signature
          return toEvmHexString(testSignature, true)
      elif recoveredPubKey.len == 65 and publicKey.len == 65:
        # Both are uncompressed, compare directly
        if recoveredPubKey == publicKey:
          return toEvmHexString(testSignature, true)
    except Exception as e:
      echo "Recovery attempt failed for recoveryId ", rawRecoveryId, ": ", e.msg
      continue
  
  # If no valid recovery ID found, return with default v=27 (recoveryId=0)
  echo "Warning: Could not find valid recovery ID, using default v=27"
  var fallbackSignature = newSeq[uint8](65)
  for i in 0..<32:
    fallbackSignature[i] = r[i]
  for i in 0..<32:
    fallbackSignature[i+32] = s[i]
  fallbackSignature[64] = 27  # Default Ethereum v value for recoveryId=0
  
  return toEvmHexString(fallbackSignature, true)
