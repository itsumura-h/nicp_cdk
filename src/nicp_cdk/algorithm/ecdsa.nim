## ECDSA Signature Verification Module
## 
## This module provides pure ECDSA cryptographic operations using secp256k1.
## It handles raw byte operations without 0x prefixes for low-level cryptographic processing.
## For Ethereum-specific operations with 0x prefixes, use the ethereum.nim module.

import nimcrypto/keccak
import secp256k1
import std/strutils
import std/sequtils

type
  EcdsaError* = object of ValueError

# バイト列を16進数文字列に変換するヘルパー関数
proc toHexString*(bytes: seq[uint8]): string =
  result = ""
  for b in bytes:
    result.add(b.toHex(2))

# 署名形式を分析する関数
proc analyzeSignatureFormat*(signature: seq[uint8]):string =
  echo "=== Signature Format Analysis ==="
  echo "Length: ", signature.len
  if signature.len > 0:
    echo "First byte: 0x", signature[0].toHex(2)
    
    if signature[0] == 0x30:
      result = "DER (ASN.1 SEQUENCE)"
      if signature.len >= 2:
        echo "Length field: ", signature[1]
        if signature.len >= 4:
          echo "First INTEGER tag: 0x", signature[2].toHex(2)
          echo "First INTEGER length: ", signature[3]
    elif signature.len == 64:
      result = "Raw (r||s, 32+32 bytes)"
    elif signature.len == 65:
      result = "Ethereum (r||s||v, 32+32+1 bytes)"
    else:
      result = "Unknown"
  
  # 16進数表示（最初の16バイト）
  if signature.len > 0:
    let displayLen = min(signature.len, 16)
    echo "First ", displayLen, " bytes: ", signature[0..<displayLen].toHexString()
  
  # DER形式の詳細解析
  if signature.len > 0 and signature[0] == 0x30:
    echo "=== DER Structure Analysis ==="
    if signature.len >= 2:
      let totalLen = signature[1].int
      echo "Total length: ", totalLen
      
      if signature.len >= 4:
        let rTag = signature[2]
        let rLen = signature[3].int
        echo "R component - Tag: 0x", rTag.toHex(2), ", Length: ", rLen
        
        if signature.len >= 6 + rLen:
          let sTag = signature[4 + rLen]
          let sLen = signature[5 + rLen].int
          echo "S component - Tag: 0x", sTag.toHex(2), ", Length: ", sLen
          
          # R値の表示
          if rLen > 0 and signature.len >= 4 + rLen:
            let rStart = 4
            let rEnd = rStart + rLen
            echo "R value: ", signature[rStart..<rEnd].toHexString()
          
          # S値の表示
          if sLen > 0 and signature.len >= 6 + rLen + sLen:
            let sStart = 6 + rLen
            let sEnd = sStart + sLen
            echo "S value: ", signature[sStart..<sEnd].toHexString()

type
  EcdsaVerificationError* = object of CatchableError
  SignatureFormatError* = object of CatchableError

proc hexToBytes*(hexStr: string): seq[uint8] =
  ## Convert hex string to byte sequence
  echo "=== hexToBytes Debug ==="
  echo "Input hex string: ", hexStr
  echo "Input length: ", hexStr.len
  
  var cleanHex = hexStr
  if cleanHex.startsWith("0x"):
    cleanHex = cleanHex[2..^1]
  
  echo "Clean hex string: ", cleanHex
  echo "Clean hex length: ", cleanHex.len
  
  if cleanHex.len mod 2 != 0:
    echo "Error: Hex string length must be even"
    raise newException(ValueError, "Hex string length must be even")
  
  result = newSeq[uint8](cleanHex.len div 2)
  for i in 0..<result.len:
    let hexByte = cleanHex[i*2..i*2+1]
    try:
      result[i] = parseHexInt(hexByte).uint8
    except ValueError:
      echo "Error: Invalid hex character at position ", i*2, ": ", hexByte
      raise newException(ValueError, "Invalid hex character: " & hexByte)
  
  echo "Output bytes length: ", result.len
  echo "Output bytes: ", result.toHexString()
  echo "=== End hexToBytes Debug ==="

proc keccak256Hash*(message: string): seq[uint8] =
  ## Calculate Keccak-256 hash of message
  echo "=== keccak256Hash Debug ==="
  echo "Input message: ", message
  echo "Input message length: ", message.len
  
  var keccakCtx: keccak256
  keccakCtx.init()
  keccakCtx.update(message)
  let hash = keccakCtx.finish()
  
  # Convert array to seq properly
  result = newSeq[uint8](32)
  for i in 0..<32:
    result[i] = hash.data[i]
  
  echo "Hash result length: ", result.len
  echo "Hash result: ", result.toHexString()
  echo "=== End keccak256Hash Debug ==="

proc verifyEcdsaSignature*(
  messageHash: seq[uint8],
  signature: seq[uint8],
  publicKey: seq[uint8]
): bool =
  echo "=== verifyEcdsaSignature Debug ==="
  echo "Message hash length: ", messageHash.len
  echo "Message hash: ", messageHash.toHexString()
  echo "Signature length: ", signature.len
  echo "Signature: ", signature.toHexString()
  echo "Public key length: ", publicKey.len
  echo "Public key: ", publicKey.toHexString()
  
  # 署名形式の詳細分析
  let signatureFormat = analyzeSignatureFormat(signature)
  echo "Signature format: ", signatureFormat
  
  try:
    # メッセージハッシュの検証
    if messageHash.len != 32:
      echo "Error: Message hash must be 32 bytes"
      return false
    
    # 公開鍵の検証
    if publicKey.len != 33:
      echo "Error: Public key must be 33 bytes (compressed format)"
      return false
    
    # Raw形式の署名を処理 (64バイト)
    if signature.len == 64:
      echo "Raw signature detected (64 bytes), processing..."
      
      # Raw署名からr値とs値を抽出
      let rBytes = signature[0..<32]
      let sBytes = signature[32..<64]
      
      echo "R bytes: ", rBytes.toHexString()
      echo "S bytes: ", sBytes.toHexString()
      
      # s値の正規化（Low-S enforcement）
      # secp256k1の群の位数（order）
      let secp256k1Order = hexToBytes("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141")
      
      # s値をbig-endianで比較
      var normalizedSBytes = sBytes
      
      # s値が群の位数の半分より大きい場合は正規化
      var needsNormalization = false
      
      # 簡単な比較：s値の最初のバイトが0x7F以上の場合は正規化が必要
      if sBytes[0] >= 0x7F:
        needsNormalization = true
        echo "S value needs normalization (high-S detected)"
        
        # s_normalized = order - s の計算
        # 簡単な実装：バイト配列での引き算
        var carry = 0
        for i in countdown(31, 0):
          let orderByte = secp256k1Order[i].int
          let sByte = sBytes[i].int
          let result = orderByte - sByte - carry
          if result < 0:
            normalizedSBytes[i] = (result + 256).uint8
            carry = 1
          else:
            normalizedSBytes[i] = result.uint8
            carry = 0
        
        echo "Normalized S bytes: ", normalizedSBytes.toHexString()
      else:
        echo "S value is already normalized (low-S)"
      
      # 正規化されたs値を使用して署名を再構築
      var normalizedSignature = newSeq[uint8](64)
      for i in 0..<32:
        normalizedSignature[i] = rBytes[i]
      for i in 0..<32:
        normalizedSignature[i + 32] = normalizedSBytes[i]
      
      echo "Normalized signature: ", normalizedSignature.toHexString()
      
      # 直接secp256k1ライブラリのfromRaw関数を使用
      let rawSigResult = SkSignature.fromRaw(normalizedSignature)
      if rawSigResult.isOk:
        echo "Raw signature parsed successfully with fromRaw"
        
        let skSignature = rawSigResult.get()
        
        # 公開鍵をパース
        let pubkeyResult = SkPublicKey.fromRaw(publicKey)
        if pubkeyResult.isErr:
          echo "Error: Failed to parse public key: ", pubkeyResult.error
          return false
        
        let pubkey = pubkeyResult.get()
        echo "Public key parsed successfully"
        
        # メッセージハッシュを32バイト配列に変換
        var messageArray: array[32, byte]
        for i in 0..<32:
          messageArray[i] = messageHash[i].byte
        let message = SkMessage(messageArray)
        
        # 署名検証
        let verifyResult = skSignature.verify(message, pubkey)
        echo "Verification result: ", verifyResult
        return verifyResult
      else:
        echo "fromRaw failed, trying DER construction..."
        
        # r値とs値を使ってDER形式の署名を構築
        var derSignature = newSeq[uint8]()
        
        # SEQUENCE tag (0x30)
        derSignature.add(0x30'u8)
        
        # r値の処理（先頭バイトが0x80以上の場合は0x00を追加）
        var rForDer = rBytes
        if rForDer[0] >= 0x80:
          rForDer = @[0x00'u8] & rForDer
        
        # s値の処理（先頭バイトが0x80以上の場合は0x00を追加）
        var sForDer = sBytes
        if sForDer[0] >= 0x80:
          sForDer = @[0x00'u8] & sForDer
        
        # 全体の長さを計算
        let totalLength = 2 + rForDer.len + 2 + sForDer.len
        derSignature.add(totalLength.uint8)
        
        # r値のINTEGER
        derSignature.add(0x02'u8)  # INTEGER tag
        derSignature.add(rForDer.len.uint8)  # r length
        derSignature.add(rForDer)  # r value
        
        # s値のINTEGER
        derSignature.add(0x02'u8)  # INTEGER tag
        derSignature.add(sForDer.len.uint8)  # s length
        derSignature.add(sForDer)  # s value
        
        echo "Constructed DER signature: ", derSignature.toHexString()
        
        # DER署名をパースしてSkSignatureを作成
        let derSigResult = SkSignature.fromDer(derSignature)
        if derSigResult.isErr:
          echo "Error: Failed to parse constructed DER signature: ", derSigResult.error
          return false
        
        let skSignature = derSigResult.get()
        echo "DER signature parsed successfully"
        
        # 公開鍵をパース
        let pubkeyResult = SkPublicKey.fromRaw(publicKey)
        if pubkeyResult.isErr:
          echo "Error: Failed to parse public key: ", pubkeyResult.error
          return false
        
        let pubkey = pubkeyResult.get()
        echo "Public key parsed successfully"
        
        # メッセージハッシュを32バイト配列に変換
        var messageArray: array[32, byte]
        for i in 0..<32:
          messageArray[i] = messageHash[i].byte
        let message = SkMessage(messageArray)
        
        # 署名検証
        let verifyResult = skSignature.verify(message, pubkey)
        echo "Verification result: ", verifyResult
        return verifyResult
    
    # DER形式の署名を処理
    elif signature.len > 6 and signature[0] == 0x30:
      echo "DER signature detected, processing..."
      
      # DER署名をパースしてSkSignatureを作成
      let derSigResult = SkSignature.fromDer(signature)
      if derSigResult.isErr:
        echo "Error: Failed to parse DER signature: ", derSigResult.error
        return false
      
      let skSignature = derSigResult.get()
      echo "DER signature parsed successfully"
      
      # 公開鍵をパース
      let pubkeyResult = SkPublicKey.fromRaw(publicKey)
      if pubkeyResult.isErr:
        echo "Error: Failed to parse public key: ", pubkeyResult.error
        return false
      
      let pubkey = pubkeyResult.get()
      echo "Public key parsed successfully"
      
      # メッセージハッシュを32バイト配列に変換
      var messageArray: array[32, byte]
      for i in 0..<32:
        messageArray[i] = messageHash[i].byte
      let message = SkMessage(messageArray)
      
      # 署名検証
      let verifyResult = skSignature.verify(message, pubkey)
      echo "Verification result: ", verifyResult
      return verifyResult
    
    else:
      echo "Error: Unsupported signature format. Expected 64 bytes (Raw) or DER format"
      return false
    
  except Exception as e:
    echo "Exception in verifyEcdsaSignature: ", e.msg
    result = false


proc verifyWithPublicKey*(
  publicKeyHex: string,
  message: string,
  signatureHex: string
): bool =
  ## Verify signature using public key in hex format (0x prefix optional)
  
  try:
    # Convert hex public key to bytes
    let publicKey = hexToBytes(publicKeyHex)
    
    # Hash the message
    let messageHash = keccak256Hash(message)
    
    # Convert hex signature to bytes
    let signatureBytes = hexToBytes(signatureHex)
    
    # Verify signature
    return verifyEcdsaSignature(messageHash, signatureBytes, publicKey)
    
  except Exception as e:
    echo "Public key verification error: ", e.msg
    return false


proc verifyWithHash*(
  publicKeyHex: string,
  messageHashHex: string,
  signatureHex: string
): bool =
  ## Verify signature using pre-hashed message (0x prefix optional)
  
  try:
    # Convert hex public key to bytes
    let publicKey = hexToBytes(publicKeyHex)
    
    # Convert hex message hash to bytes
    let messageHash = hexToBytes(messageHashHex)
    
    # Convert hex signature to bytes
    let signatureBytes = hexToBytes(signatureHex)
    
    # Verify signature
    return verifyEcdsaSignature(messageHash, signatureBytes, publicKey)
    
  except Exception as e:
    echo "Hash verification error: ", e.msg
    return false





proc validateSignatureFormat*(signatureHex: string): bool =
  ## Validate signature hex format (0x prefix optional)
  try:
    let cleanSig = if signatureHex.startsWith("0x"): signatureHex[2..^1] else: signatureHex
    return cleanSig.len == 128 or cleanSig.len == 130
  except:
          return false


proc verifyEcdsaSignatureWithHex*(
  messageHash: seq[uint8],
  signatureHex: string,
  publicKey: seq[uint8]
): bool =
  ## Verify ECDSA signature with hex string signature
  let signatureBytes = hexToBytes(signatureHex)
  return verifyEcdsaSignature(messageHash, signatureBytes, publicKey)

proc verifyEcdsaSignatureWithHexKey*(
  messageHash: seq[uint8],
  signatureBytes: seq[uint8],
  publicKeyHex: string
): bool =
  ## Verify ECDSA signature with hex string public key
  let publicKey = hexToBytes(publicKeyHex)
  return verifyEcdsaSignature(messageHash, signatureBytes, publicKey)

proc testSecp256k1Operation*(): bool =
  ## Test secp256k1 library operation with known test vectors
  echo "=== Testing secp256k1 library ==="
  
  try:
    # Test vector from secp256k1 library
    let testMessage = "hello world"
    let testHash = keccak256Hash(testMessage)
    
    # Create a test secret key
    let secretKeyBytes = hexToBytes("0000000000000000000000000000000000000000000000000000000000000001")
    let secretKeyResult = SkSecretKey.fromRaw(secretKeyBytes)
    if secretKeyResult.isErr:
      echo "Failed to create secret key: ", secretKeyResult.error
      return false
    
    let secretKey = secretKeyResult.get()
    
    # Get public key
    let publicKey = secretKey.toPublicKey()
    
    # Create message
    var messageArray: array[32, byte]
    for i in 0..<32:
      messageArray[i] = testHash[i].byte
    let message = SkMessage(messageArray)
    
    # Sign message
    let signature = secretKey.sign(message)
    
    # Verify signature
    let isValid = signature.verify(message, publicKey)
    
    echo "Test signature verification result: ", isValid
    return isValid
    
  except Exception as e:
    echo "Test failed with exception: ", e.msg
    return false


proc createTestSignature*(): string =
  ## Create a test signature for demonstration purposes
  ## This is not a real signature - just for testing the parsing logic
  return "1".repeat(128)  # 64 bytes of 0x01 (no 0x prefix)


proc tryDerDecoding*(signature: seq[uint8]): bool =
  ## Try to decode signature as DER format and check if it's valid DER
  try:
    echo "=== Trying DER decoding ==="
    echo "Signature: ", signature.toHexString()
    
    # Check if it starts with 0x30 (SEQUENCE tag)
    if signature.len < 6:
      echo "Signature too short for DER"
      return false
    
    if signature[0] != 0x30:
      echo "Not DER format (doesn't start with 0x30)"
      return false
    
    echo "Starts with 0x30 - could be DER"
    
    # Try to parse with secp256k1 library
    let derResult = SkSignature.fromDer(signature)
    if derResult.isOk:
      echo "Successfully parsed as DER signature"
      return true
    else:
      echo "Failed to parse as DER: ", derResult.error
      return false
      
  except Exception as e:
    echo "Exception in DER decoding: ", e.msg
    return false
