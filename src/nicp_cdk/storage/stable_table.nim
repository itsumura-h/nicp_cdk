import std/endians
import std/tables

import ./serialization
import ./stable_memory

const
  TableMagic = [byte('S'), byte('T'), byte('B'), byte('L')]
  TableVersion = 1'u32
  TableHeaderSize = 32'u64

type EntryInfo = object
  offset: uint64
  keyLen: uint32
  valueLen: uint32

type IcStableTable*[K, V] = object
  baseOffset: uint64
  count: uint64
  dataEnd: uint64
  index: Table[string, EntryInfo]

proc bytesToString(data: openArray[byte]): string =
  result = newString(data.len)
  if data.len > 0:
    copyMem(addr result[0], unsafeAddr data[0], data.len)

proc stringToBytes(data: string): seq[byte] =
  result = newSeq[byte](data.len)
  if data.len > 0:
    copyMem(addr result[0], unsafeAddr data[0], data.len)

proc dataStart(t: IcStableTable): uint64 =
  t.baseOffset + TableHeaderSize

proc writeHeader(t: IcStableTable) =
  var header = newSeq[byte](int(TableHeaderSize))
  header[0] = TableMagic[0]
  header[1] = TableMagic[1]
  header[2] = TableMagic[2]
  header[3] = TableMagic[3]
  var offset = 4
  var version = TableVersion
  littleEndian32(addr header[offset], addr version)
  offset += 4
  var count = t.count
  littleEndian64(addr header[offset], addr count)
  offset += 8
  var dataEnd = t.dataEnd
  littleEndian64(addr header[offset], addr dataEnd)
  stableWrite(t.baseOffset, header)

proc readHeader(t: var IcStableTable): bool =
  if stableSizeBytes() < t.baseOffset + TableHeaderSize:
    return false
  let header = stableRead(t.baseOffset, TableHeaderSize)
  if header.len < int(TableHeaderSize):
    return false
  if header[0] != TableMagic[0] or header[1] != TableMagic[1] or
     header[2] != TableMagic[2] or header[3] != TableMagic[3]:
    return false
  var offset = 4
  let version = deserialize[uint32](header, offset)
  if version != TableVersion:
    return false
  t.count = deserialize[uint64](header, offset)
  t.dataEnd = deserialize[uint64](header, offset)
  let minStart = dataStart(t)
  if t.dataEnd < minStart:
    t.dataEnd = minStart
  let maxEnd = stableSizeBytes()
  if t.dataEnd > maxEnd:
    t.dataEnd = maxEnd
  result = true

proc rebuildIndex[K, V](t: var IcStableTable[K, V]) =
  t.index.clear()
  let minStart = dataStart(t)
  var offset = minStart
  let maxEnd = t.dataEnd
  var uniqueCount = 0'u64
  while offset + 8'u64 <= maxEnd:
    let lensBytes = stableRead(offset, 8)
    var lensOffset = 0
    let keyLen = deserialize[uint32](lensBytes, lensOffset)
    let valueLen = deserialize[uint32](lensBytes, lensOffset)
    let entrySize = 8'u64 + uint64(keyLen) + uint64(valueLen)
    if offset + entrySize > maxEnd:
      break
    let keyBytes = stableRead(offset + 8'u64, uint64(keyLen))
    let keyStr = bytesToString(keyBytes)
    if not t.index.hasKey(keyStr):
      uniqueCount += 1
    t.index[keyStr] = EntryInfo(offset: offset, keyLen: keyLen, valueLen: valueLen)
    offset += entrySize
  t.count = uniqueCount
  t.dataEnd = offset
  writeHeader(t)

proc initIcStableTable*[K, V](baseOffset: uint64 = 0): IcStableTable[K, V] =
  result.baseOffset = baseOffset
  result.index = initTable[string, EntryInfo]()
  if not readHeader(result):
    result.count = 0
    result.dataEnd = dataStart(result)
    writeHeader(result)
  rebuildIndex(result)

proc hasKey*[K, V](t: IcStableTable[K, V], key: K): bool =
  let keyBytes = serialize(key)
  let keyStr = bytesToString(keyBytes)
  result = t.index.hasKey(keyStr)

proc len*[K, V](t: IcStableTable[K, V]): int =
  int(t.count)

proc `[]`*[K, V](t: var IcStableTable[K, V], key: K): V =
  let keyBytes = serialize(key)
  let keyStr = bytesToString(keyBytes)
  if not t.index.hasKey(keyStr):
    raise newException(KeyError, "key not found")
  let info = t.index[keyStr]
  let valueOffset = info.offset + 8'u64 + uint64(info.keyLen)
  let valueBytes = stableRead(valueOffset, uint64(info.valueLen))
  var valuePos = 0
  result = deserialize[V](valueBytes, valuePos)

proc `[]=`*[K, V](t: var IcStableTable[K, V], key: K, value: V) =
  let keyBytes = serialize(key)
  let valueBytes = serialize(value)
  let keyStr = bytesToString(keyBytes)
  if not t.index.hasKey(keyStr):
    t.count += 1
  let entryOffset = t.dataEnd
  let keyLen = uint32(keyBytes.len)
  let valueLen = uint32(valueBytes.len)
  var lensBytes = newSeq[byte](8)
  var keyLenLe = keyLen
  var valueLenLe = valueLen
  littleEndian32(addr lensBytes[0], addr keyLenLe)
  littleEndian32(addr lensBytes[4], addr valueLenLe)
  stableWrite(entryOffset, lensBytes)
  stableWrite(entryOffset + 8'u64, keyBytes)
  stableWrite(entryOffset + 8'u64 + uint64(keyLen), valueBytes)
  t.dataEnd = entryOffset + 8'u64 + uint64(keyLen) + uint64(valueLen)
  t.index[keyStr] = EntryInfo(offset: entryOffset, keyLen: keyLen, valueLen: valueLen)
  writeHeader(t)

proc clear*[K, V](t: var IcStableTable[K, V]) =
  t.index.clear()
  t.count = 0
  t.dataEnd = dataStart(t)
  writeHeader(t)

iterator pairs*[K, V](t: IcStableTable[K, V]): (K, V) =
  for keyStr, info in t.index.pairs:
    let keyBytes = stringToBytes(keyStr)
    var keyPos = 0
    let key = deserialize[K](keyBytes, keyPos)
    let valueOffset = info.offset + 8'u64 + uint64(info.keyLen)
    let valueBytes = stableRead(valueOffset, uint64(info.valueLen))
    var valuePos = 0
    let value = deserialize[V](valueBytes, valuePos)
    yield (key, value)

iterator keys*[K, V](t: IcStableTable[K, V]): K =
  for keyStr, _ in t.index.pairs:
    let keyBytes = stringToBytes(keyStr)
    var keyPos = 0
    yield deserialize[K](keyBytes, keyPos)

iterator values*[K, V](t: IcStableTable[K, V]): V =
  for _, info in t.index.pairs:
    let valueOffset = info.offset + 8'u64 + uint64(info.keyLen)
    let valueBytes = stableRead(valueOffset, uint64(info.valueLen))
    var valuePos = 0
    yield deserialize[V](valueBytes, valuePos)
