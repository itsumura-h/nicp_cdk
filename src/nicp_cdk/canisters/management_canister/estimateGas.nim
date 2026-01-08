proc addMargin20*(cost: uint64): uint64 =
  cost + (cost div 5)

proc addCap*(a, b: uint64): uint64 =
  if a > high(uint64) - b: high(uint64) else: a + b

proc mulCap*(a, b: uint64): uint64 =
  if a == 0 or b == 0: return 0
  if a > high(uint64) div b: high(uint64) else: a * b

proc costBufferToUint64*(costBuffer: array[16, uint8]): uint64 =
  var exactCost: uint64 = 0
  for i in 0..<8:
    exactCost = exactCost or (uint64(costBuffer[i]) shl (i * 8))
  exactCost
