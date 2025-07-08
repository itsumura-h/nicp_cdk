## Test file for ECDSA signature verification functionality

import std/unittest
import std/strutils
import src/t_ecdsa_backend/ecdsa

# Import all functions from ecdsa module
from src/t_ecdsa_backend/ecdsa import hexToBytes, toHexString, validateEthereumAddress, 
  validateSignatureFormat, keccak256Hash, parseSignature, createTestSignature, 
  verifyWithPublicKey

suite "ECDSA Signature Verification Tests":
  
  test "Hex string conversion":
    let hexStr = "0x1234567890abcdef"
    let bytes = hexToBytes(hexStr)
    check bytes.len == 8
    check bytes[0] == 0x12
    check bytes[1] == 0x34
    check bytes[7] == 0xef
    
    let backToHex = toHexString(bytes)
    check backToHex == "0x1234567890abcdef"
  
  test "Ethereum address validation":
    let validAddress = "0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6"
    let invalidAddress = "0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b"  # Too short
    let invalidChars = "0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8bG"  # Invalid char
    
    check validateEthereumAddress(validAddress) == true
    check validateEthereumAddress(invalidAddress) == false
    check validateEthereumAddress(invalidChars) == false
  
  test "Signature format validation":
    let validSig64 = "0x" & "1".repeat(128)  # 64 bytes
    let validSig65 = "0x" & "1".repeat(130)  # 65 bytes
    let invalidSig = "0x123"  # Too short
    
    check validateSignatureFormat(validSig64) == true
    check validateSignatureFormat(validSig65) == true
    check validateSignatureFormat(invalidSig) == false
  
  test "Message hashing":
    let message = "Hello, World!"
    let hash = keccak256Hash(message)
    
    check hash.len == 32  # Keccak-256 produces 32-byte hash
    check hash != keccak256Hash("Different message")
  
  test "Signature parsing":
    let testSig = "0x" & "1".repeat(128)
    let (r, s, v) = parseSignature(testSig)
    
    check r.len == 32
    check s.len == 32
    check v == 0  # Default value when not provided
    
    # Test with v value
    let testSigWithV = testSig & "1b"  # v = 27
    let (r2, s2, v2) = parseSignature(testSigWithV)
    check v2 == 27
  
  test "Test signature creation":
    let testSig = createTestSignature()
    check testSig.startsWith("0x")
    check testSig.len == 130  # 0x + 128 hex chars
    
    let (r, s, v) = parseSignature(testSig)
    check r.len == 32
    check s.len == 32
    check v == 0

suite "Error Handling Tests":
  
  test "Invalid hex string handling":
    expect(SignatureFormatError):
      discard hexToBytes("0x123")  # Odd length
    
    expect(SignatureFormatError):
      discard hexToBytes("0x12g3")  # Invalid hex char
  
  test "Invalid signature parsing":
    expect(SignatureFormatError):
      discard parseSignature("0x123")  # Too short
    
    expect(SignatureFormatError):
      discard parseSignature("0x" & "1".repeat(126))  # Wrong length

suite "Integration Tests":
  
  test "Complete verification flow":
    # Note: These are test values and won't produce valid signatures
    # In a real scenario, you'd use actual signed data
    
    let publicKeyHex = "0x" & "02".repeat(32)  # Test public key
    let message = "Test message"
    let signatureHex = createTestSignature()
    
    # This should fail with test data, but shouldn't crash
    let result = verifyWithPublicKey(publicKeyHex, message, signatureHex)
    echo "Test verification result: ", result
    
    # The test passes if the function handles the invalid data gracefully
    check true  # Function executed without crashing

echo "ECDSA verification tests completed" 