## Evm Address Conversion Module
## 
## This module provides functionality to convert ICP ECDSA public keys 
## to Evm addresses using nimcrypto library.

import std/strutils
import std/sequtils
import nimcrypto/keccak
import secp256k1

type
  EthereumConversionError* = object of CatchableError
  
  PublicKeyFormat* = enum
    Compressed,    # 33 bytes (0x02/0x03 + 32 bytes)
    Uncompressed   # 65 bytes (0x04 + 64 bytes)


proc toHexString(data: seq[uint8], prefix: bool = true): string =
  ## Convert byte sequence to hex string
  let hexStr = data.mapIt(it.toHex(2)).join("")
  if prefix:
    return "0x" & hexStr.toLowerAscii()
  else:
    return hexStr.toLowerAscii()


proc detectPublicKeyFormat(pubKey: seq[uint8]): PublicKeyFormat =
  ## Detect public key format based on length and prefix
  if pubKey.len == 33 and (pubKey[0] == 0x02 or pubKey[0] == 0x03):
    return Compressed
  elif pubKey.len == 65 and pubKey[0] == 0x04:
    return Uncompressed
  else:
    raise newException(EthereumConversionError, 
      "Invalid public key format: length=" & $pubKey.len & ", prefix=0x" & 
      pubKey[0].toHex(2))


proc decompressPublicKey(compressedKey: seq[uint8]): seq[uint8] =
  ## Real secp256k1 public key decompression using status-im/nim-secp256k1
  if compressedKey.len != 33:
    raise newException(EthereumConversionError, "Compressed key must be 33 bytes")
  
  if compressedKey[0] != 0x02 and compressedKey[0] != 0x03:
    raise newException(EthereumConversionError, "Invalid compressed key prefix")
  
  try:
    # Parse compressed public key using status-im secp256k1 wrapper
    let pubkeyResult = SkPublicKey.fromRaw(compressedKey)
    if pubkeyResult.isErr:
      raise newException(EthereumConversionError, 
                        "Failed to parse compressed public key: " & $pubkeyResult.error)
    
    let pubkey = pubkeyResult.get()
    
    # Convert to uncompressed format (65 bytes)
    let uncompressedArray = pubkey.toRaw()
    
    # Convert array to seq for consistency with API
    var uncompressed = newSeq[uint8](65)
    for i in 0..<65:
      uncompressed[i] = uncompressedArray[i]
    
    return uncompressed
  except:
    raise newException(EthereumConversionError, 
                      "secp256k1 decompression failed: " & getCurrentExceptionMsg())


proc publicKeyToEvmAddress(pubKey: seq[uint8]): string =
  ## Convert public key (compressed or uncompressed) to Evm address
  var uncompressedKey: seq[uint8]
  
  let format = detectPublicKeyFormat(pubKey)
  echo "format: ", format
  case format:
  of Compressed:
    uncompressedKey = decompressPublicKey(pubKey)
  of Uncompressed:
    uncompressedKey = pubKey
  
  # Remove 0x04 prefix (first byte) to get 64-byte coordinate data
  if uncompressedKey.len != 65 or uncompressedKey[0] != 0x04:
    raise newException(EthereumConversionError, 
                      "Invalid uncompressed key format")
  
  let coordinateData = uncompressedKey[1..^1] # Remove first byte (0x04)
  
  # Keccak-256 hash the 64-byte coordinate data
  var keccakCtx: keccak256
  keccakCtx.init()
  keccakCtx.update(coordinateData)
  let hash = keccakCtx.finish()
  
  # Take the last 20 bytes of the hash as Evm address
  let addressBytes = hash.data[12..^1] # Last 20 bytes
  
  # Convert to hex string with 0x prefix
  return toHexString(addressBytes, true)


proc icpPublicKeyToEvmAddress*(icpPublicKey: seq[uint8]): string =
  ## Convert ICP ECDSA public key (33 bytes compressed) to Evm address
  ## This is the main function for ICP integration
  if icpPublicKey.len != 33:
    raise newException(EthereumConversionError, 
                      "ICP public key must be 33 bytes (compressed format)")
  
  if icpPublicKey[0] != 0x02 and icpPublicKey[0] != 0x03:
    raise newException(EthereumConversionError, 
                      "ICP public key must have valid compression prefix (0x02 or 0x03)")
  
  return publicKeyToEvmAddress(icpPublicKey)


proc convertToEthereumAddress*(publicKeyHex: string): string =
  ## Convert hex string public key to Evm address
  try:
    # Hex文字列をbytesに変換
    let hexStr = if publicKeyHex.startsWith("0x"): publicKeyHex[2..^1] else: publicKeyHex
    var pubKeyBytes: seq[uint8] = @[]
    
    for i in countup(0, hexStr.len - 2, 2):
      let byteStr = hexStr[i..i+1]
      pubKeyBytes.add(parseHexInt(byteStr).uint8)
    
    return icpPublicKeyToEvmAddress(pubKeyBytes)
  except:
    raise newException(EthereumConversionError, 
                      "Failed to parse hex string: " & getCurrentExceptionMsg())


proc createTestUncompressedKey*(): seq[uint8] =
  ## Create a test uncompressed public key for testing
  result = newSeq[uint8](65)
  result[0] = 0x04  # Uncompressed key prefix
  # Fill with test data
  for i in 1..64:
    result[i] = uint8(i mod 256)


proc validateSecp256k1PublicKey*(pubKey: seq[uint8]): bool =
  ## Validate if a public key is valid according to secp256k1
  try:
    # Use status-im secp256k1 wrapper for validation
    let pubkeyResult = SkPublicKey.fromRaw(pubKey)
    return pubkeyResult.isOk
  except:
    return false
