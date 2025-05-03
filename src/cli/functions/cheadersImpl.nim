import std/os
import std/osproc
import std/httpclient

proc downloadFile(client: HttpClient, url: string, path: string) =
  let content = client.getContent(url)
  writeFile(path, content)


proc cheaders*(path="c_headers") =
  ## download c headers
  let targetPath = getCurrentDir() / path
  echo targetPath
  removeDir(targetPath)
  createDir(targetPath)
  const ic0Url = "https://raw.githubusercontent.com/icppWorld/icpp-pro/refs/heads/main/src/icpp/ic/ic0/ic0.h"
  const icWasiPolyfillUrl = "https://raw.githubusercontent.com/icppWorld/icpp-pro/refs/heads/main/src/icpp/ic/ic0/ic_wasi_polyfill.h"
  const wasmSymbolUrl = "https://raw.githubusercontent.com/icppWorld/icpp-pro/refs/heads/main/src/icpp/ic/icapi/wasm_symbol.h"
  let client = newHttpClient()
  defer: client.close()
  downloadFile(client, ic0Url, targetPath / "ic0.h")
  downloadFile(client, icWasiPolyfillUrl, targetPath / "ic_wasi_polyfill.h")
  downloadFile(client, wasmSymbolUrl, targetPath / "wasm_symbol.h")
  var command = "IC_C_HEADERS_PATH=" & targetPath & " echo $IC_C_HEADERS_PATH"
  echo command
  discard execCmdEx(command)
