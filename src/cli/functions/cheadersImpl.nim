import std/os
import std/strformat
import std/httpclient


proc downloadFile(client: HttpClient, url: string, path: string) =
  if fileExists(path):
    echo &"File `{path}` already exists"
    return
  
  let content = client.getContent(url)
  writeFile(path, content)


proc cHeaders*(path="/root/.ic-c-headers", force=false) =
  ## download c headers
  ## 
  ## default path: /root/.ic-c-headers
  if force:
    removeDir(path)
  
  if not dirExists(path):
    createDir(path)
  
  const ic0Url = "https://raw.githubusercontent.com/itsumura-h/nicp_cdk/refs/heads/main/src/c_headers/ic0.h"
  const icWasiPolyfillUrl = "https://raw.githubusercontent.com/itsumura-h/nicp_cdk/refs/heads/main/src/c_headers/ic_wasi_polyfill.h"
  const wasmSymbolUrl = "https://raw.githubusercontent.com/itsumura-h/nicp_cdk/refs/heads/main/src/c_headers/wasm_symbol.h"
  let client = newHttpClient()
  defer: client.close()
  downloadFile(client, ic0Url, path / "ic0.h")
  downloadFile(client, icWasiPolyfillUrl, path / "ic_wasi_polyfill.h")
  downloadFile(client, wasmSymbolUrl, path / "wasm_symbol.h")
  echo "Downloaded c headers"
  echo &"Please set the `cHeadersPath` in config.nims to `{path}`"
