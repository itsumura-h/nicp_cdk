import std/endians
import ../ic_types/ic_principal

proc serialize*(value: uint8): seq[byte] =
  result = @[byte(value)]

proc serialize*(value: int8): seq[byte] =
  result = @[byte(value)]

proc serialize*(value: uint16): seq[byte] =
  result = newSeq[byte](2)
  var le = value
  littleEndian16(addr result[0], addr le)

proc serialize*(value: int16): seq[byte] =
  result = newSeq[byte](2)
  var le = value
  littleEndian16(addr result[0], addr le)

proc serialize*(value: uint32): seq[byte] =
  result = newSeq[byte](4)
  var le = value
  littleEndian32(addr result[0], addr le)

proc serialize*(value: int32): seq[byte] =
  result = newSeq[byte](4)
  var le = value
  littleEndian32(addr result[0], addr le)

proc serialize*(value: uint64): seq[byte] =
  result = newSeq[byte](8)
  var le = value
  littleEndian64(addr result[0], addr le)

proc serialize*(value: int64): seq[byte] =
  result = newSeq[byte](8)
  var le = value
  littleEndian64(addr result[0], addr le)

proc serialize*(value: bool): seq[byte] =
  result = @[byte(if value: 1 else: 0)]

proc serialize*(value: string): seq[byte] =
  let len = uint32(value.len)
  result = newSeq[byte](4 + value.len)
  var le = len
  littleEndian32(addr result[0], addr le)
  if value.len > 0:
    copyMem(addr result[4], unsafeAddr value[0], value.len)

proc serialize*(value: Principal): seq[byte] =
  let blob = value.bytes
  let blobLen = uint32(blob.len)
  result = newSeq[byte](4 + blob.len)
  var lenLe = blobLen
  littleEndian32(addr result[0], addr lenLe)
  if blob.len > 0:
    copyMem(addr result[4], unsafeAddr blob[0], blob.len)

proc serialize*(value: int): seq[byte] =
  when sizeof(int) == 8:
    result = serialize(int64(value))
  else:
    result = serialize(int32(value))

proc serialize*(value: uint): seq[byte] =
  when sizeof(uint) == 8:
    result = serialize(uint64(value))
  else:
    result = serialize(uint32(value))

proc deserialize*[T](data: openArray[byte], offset: var int): T =
  when T is uint8:
    result = data[offset]
    offset += 1
  elif T is int8:
    result = cast[int8](data[offset])
    offset += 1
  elif T is uint16:
    var le: uint16
    littleEndian16(addr le, unsafeAddr data[offset])
    offset += 2
    result = le
  elif T is int16:
    var le: int16
    littleEndian16(addr le, unsafeAddr data[offset])
    offset += 2
    result = le
  elif T is uint32:
    var le: uint32
    littleEndian32(addr le, unsafeAddr data[offset])
    offset += 4
    result = le
  elif T is int32:
    var le: int32
    littleEndian32(addr le, unsafeAddr data[offset])
    offset += 4
    result = le
  elif T is uint64:
    var le: uint64
    littleEndian64(addr le, unsafeAddr data[offset])
    offset += 8
    result = le
  elif T is int64:
    var le: int64
    littleEndian64(addr le, unsafeAddr data[offset])
    offset += 8
    result = le
  elif T is bool:
    result = data[offset] != 0
    offset += 1
  elif T is string:
    var len: uint32
    littleEndian32(addr len, unsafeAddr data[offset])
    offset += 4
    let intLen = int(len)
    result = newString(intLen)
    if intLen > 0:
      copyMem(addr result[0], unsafeAddr data[offset], intLen)
      offset += intLen
  elif T is int:
    when sizeof(int) == 8:
      var le: int64
      littleEndian64(addr le, unsafeAddr data[offset])
      offset += 8
      result = int(le)
    else:
      var le: int32
      littleEndian32(addr le, unsafeAddr data[offset])
      offset += 4
      result = int(le)
  elif T is uint:
    when sizeof(uint) == 8:
      var le: uint64
      littleEndian64(addr le, unsafeAddr data[offset])
      offset += 8
      result = uint(le)
    else:
      var le: uint32
      littleEndian32(addr le, unsafeAddr data[offset])
      offset += 4
      result = uint(le)
  elif T is Principal:
    var len: uint32
    littleEndian32(addr len, unsafeAddr data[offset])
    offset += 4
    let blobLen = int(len)
    var blob: seq[byte]
    if blobLen > 0:
      blob = newSeq[byte](blobLen)
      copyMem(addr blob[0], unsafeAddr data[offset], blobLen)
    else:
      blob = @[]
    offset += blobLen
    result = Principal.fromBlob(blob)
  else:
    {.fatal: "Unsupported type for deserialize".}
