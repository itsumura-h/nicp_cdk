discard """
  cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg tests/algorithm/test_eth_address.nim

import unittest
import std/strutils
import ../../src/nicp_cdk/algorithm/eth_address

suite "Ethereum Address Conversion Tests":
  
  test "toHexString function":
    let testData = @[0x12'u8, 0x34, 0x56, 0xAB, 0xCD, 0xEF]
    
    # Test with prefix
    check toHexString(testData, true) == "0x123456abcdef"
    
    # Test without prefix
    check toHexString(testData, false) == "123456abcdef"
    
    # Test empty data
    check toHexString(@[], true) == "0x"
    check toHexString(@[], false) == ""
  
  test "detectPublicKeyFormat function":
    # Test compressed key (33 bytes with 0x02 prefix)
    let compressedKey = @[0x02'u8] & newSeq[uint8](32)
    check detectPublicKeyFormat(compressedKey) == Compressed
    
    # Test compressed key (33 bytes with 0x03 prefix)
    let compressedKey2 = @[0x03'u8] & newSeq[uint8](32)
    check detectPublicKeyFormat(compressedKey2) == Compressed
    
    # Test uncompressed key (65 bytes with 0x04 prefix)
    let uncompressedKey = @[0x04'u8] & newSeq[uint8](64)
    check detectPublicKeyFormat(uncompressedKey) == Uncompressed
    
    # Test invalid formats
    expect(EthereumConversionError):
      discard detectPublicKeyFormat(@[0x01'u8] & newSeq[uint8](32))  # Invalid prefix
    
    expect(EthereumConversionError):
      discard detectPublicKeyFormat(newSeq[uint8](32))  # Wrong length
    
    expect(EthereumConversionError):
      discard detectPublicKeyFormat(newSeq[uint8](66))  # Wrong length
  
  test "createTestUncompressedKey function":
    # Test uncompressed key creation
    let uncompressedKey = createTestUncompressedKey()
    check uncompressedKey.len == 65
    check uncompressedKey[0] == 0x04
    check detectPublicKeyFormat(uncompressedKey) == Uncompressed
  
  test "publicKeyToEthereumAddress with test keys":
    # Test with uncompressed key
    let uncompressedKey = createTestUncompressedKey()
    let address = publicKeyToEthereumAddress(uncompressedKey)
    check address.startsWith("0x")
    check address.len == 42  # 0x + 40 hex characters
  
  test "icpPublicKeyToEvmAddress with sample data":
    # Test with the actual ICP public key from the problem
    let icpPubKey = @[2'u8, 235, 128, 181, 135, 165, 54, 43, 7, 246, 7, 102, 
                      40, 113, 66, 255, 248, 229, 251, 254, 153, 234, 201, 48, 
                      207, 165, 219, 132, 147, 168, 48, 200, 55]
    
    let ethAddress = icpPublicKeyToEvmAddress(icpPubKey)
    
    # Basic validation
    check ethAddress.startsWith("0x")
    check ethAddress.len == 42
    
    # Check that it's valid hex
    let hexPart = ethAddress[2..^1]
    for c in hexPart:
      check c in "0123456789abcdef"
    
    echo "Generated Ethereum address: ", ethAddress
  
  test "icpPublicKeyToEvmAddress validation":
    # Test with wrong length
    expect(EthereumConversionError):
      discard icpPublicKeyToEvmAddress(newSeq[uint8](32))  # Too short
    
    expect(EthereumConversionError):
      discard icpPublicKeyToEvmAddress(newSeq[uint8](34))  # Too long
    
    # Test with empty sequence
    expect(EthereumConversionError):
      discard icpPublicKeyToEvmAddress(@[])
  
  test "convertToEthereumAddress function":
    # Test hex string conversion
    let hexPubKey = "0x02eb80b587a5362b07f60766287142fff8e5fbfe99eac930cfa5db8493a830c837"
    let expectedBytes = @[2'u8, 235, 128, 181, 135, 165, 54, 43, 7, 246, 7, 102, 
                         40, 113, 66, 255, 248, 229, 251, 254, 153, 234, 201, 48, 
                         207, 165, 219, 132, 147, 168, 48, 200, 55]
    
    let expectedAddress = icpPublicKeyToEvmAddress(expectedBytes)
    let convertedAddress = convertToEthereumAddress(hexPubKey)
    check convertedAddress == expectedAddress
  
  test "validateSecp256k1PublicKey function":
    # Valid compressed key
    let validCompressed = @[2'u8, 235, 128, 181, 135, 165, 54, 43, 7, 246, 7, 102, 
                           40, 113, 66, 255, 248, 229, 251, 254, 153, 234, 201, 48, 
                           207, 165, 219, 132, 147, 168, 48, 200, 55]
    check validateSecp256k1PublicKey(validCompressed) == true
    
    # Invalid key (wrong length)
    let invalidKey = @[2'u8, 3, 4]
    check validateSecp256k1PublicKey(invalidKey) == false
    
    # Invalid key (wrong prefix)
    var invalidPrefix = validCompressed
    invalidPrefix[0] = 0x01
    check validateSecp256k1PublicKey(invalidPrefix) == false
  
  test "getImplementationInfo function":
    let info = getImplementationInfo()
    check info == "Real secp256k1 implementation"
    echo "Implementation info: ", info

suite "Performance and Consistency Tests":
  test "address consistency":
    # Same input should always produce same output
    let icpPubKey = @[2'u8, 235, 128, 181, 135, 165, 54, 43, 7, 246, 7, 102, 
                      40, 113, 66, 255, 248, 229, 251, 254, 153, 234, 201, 48, 
                      207, 165, 219, 132, 147, 168, 48, 200, 55]
    
    let address1 = icpPublicKeyToEvmAddress(icpPubKey)
    let address2 = icpPublicKeyToEvmAddress(icpPubKey)
    
    check address1 == address2
    echo "Consistent address: ", address1 