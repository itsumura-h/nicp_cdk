import ./functions/ic0
import ./functions/newImpl

when isMainModule:
  import cligen
  dispatchMulti(
    [ic0.ic0], [newImpl.new]
  )
