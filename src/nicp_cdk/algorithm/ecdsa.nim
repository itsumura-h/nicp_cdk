## ECDSA Signature Verification Module
## 
## This module provides pure ECDSA cryptographic operations using secp256k1.
## It handles raw byte operations without 0x prefixes for low-level cryptographic processing.
## For Ethereum-specific operations with 0x prefixes, use the ethereum.nim module.

import nimcrypto/keccak
import secp256k1
import std/strutils

type
  EcdsaError* = object of ValueError

# バイト列を16進数文字列に変換するヘルパー関数
proc toHexString*(bytes: seq[uint8]): string =
  result = ""
  for b in bytes:
    result.add(b.toHex(2))


type
  EcdsaVerificationError* = object of CatchableError
  SignatureFormatError* = object of CatchableError


proc hexToBytes*(hexStr: string): seq[uint8] =
  ## Convert hex string to byte sequence
  var cleanHex = hexStr
  if cleanHex.startsWith("0x"):
    cleanHex = cleanHex[2..^1]
  
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


proc keccak256Hash*(message: string): seq[uint8] =
  ## Calculate Keccak-256 hash of message
  var keccakCtx: keccak256
  keccakCtx.init()
  keccakCtx.update(message)
  let hash = keccakCtx.finish()
  
  # Convert array to seq properly
  result = newSeq[uint8](32)
  for i in 0..<32:
    result[i] = hash.data[i]


proc verifyEcdsaSignature*(
  messageHash: seq[uint8],
  signature: seq[uint8],
  publicKey: seq[uint8]
): bool =
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
