import ./functions/new_impl
import ./functions/c_headers_impl

when isMainModule:
  import cligen
  dispatchMulti(
    [new_impl.new], [c_headers_impl.cHeaders]
  )
