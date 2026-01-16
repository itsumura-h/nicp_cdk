# import std/os
import std/strutils
import std/strformat
import std/os
import std/osproc
import std/json
import illwill


const configContent = """
import std/os

--mm: "orc"
--threads: "off"
--cpu: "wasm32"
--os: "linux"
--nomain
--cc: "clang"
--define: "useMalloc"

# Enforce static linking for the WASI target to make it self-contained, similar to icpp-pro
switch("passC", "-target wasm32-wasi")
switch("passL", "-target wasm32-wasi")
switch("passL", "-static") # Statically link necessary libraries
switch("passL", "-nostartfiles") # Do not link standard startup files
switch("passL", "-Wl,--no-entry") # Do not enforce an entry point
switch("passC", "-fno-exceptions") # Do not use exceptions

# optimize
when defined(release):
  switch("passC", "-Os") # optimize for size
  switch("passC", "-flto") # link time optimization for compiler
  switch("passL", "-flto") # link time optimization for linker

# ic0.h path
# to download, run `ndfx c_headers`
let cHeadersPath = "/root/.ic-c-headers"
switch("passC", "-I" & cHeadersPath)
switch("passL", "-L" & cHeadersPath)

# ic wasi polyfill path
let icWasiPolyfillPath = getEnv("IC_WASI_POLYFILL_PATH")
switch("passL", "-L" & icWasiPolyfillPath)
switch("passL", "-lic_wasi_polyfill")

# WASI SDK sysroot / include
let wasiSysroot = getEnv("WASI_SDK_PATH") / "share/wasi-sysroot"
switch("passC", "--sysroot=" & wasiSysroot)
switch("passL", "--sysroot=" & wasiSysroot)
switch("passC", "-I" & wasiSysroot & "/include")

# WASI emulation settings
switch("passC", "-D_WASI_EMULATED_SIGNAL")
switch("passL", "-lwasi-emulated-signal")
"""

const mainCode = """
import nicp_cdk

proc greet() {.query.} =
  let request = Request.new()
  let name = request.getStr(0)
  reply("Hello, " & name & "!")
"""

const didContent = """
service : {
  greet : (text) -> (text) query;
};
"""

proc buildContent(projectName: string):string = &"""
#!/bin/bash
rm -fr ./*.wasm
rm -fr ./*.wat

# for debug build
echo "nim c -o:wasi.wasm src/{projectName}_backend/main.nim"
nim c -o:wasi.wasm src/{projectName}_backend/main.nim

# for release build
# echo "nim c -d:release -o:wasi.wasm src/{projectName}_backend/main.nim"
# nim c -d:release -o:wasi.wasm src/{projectName}_backend/main.nim

echo "wasi2ic wasi.wasm main.wasm"
wasi2ic wasi.wasm main.wasm
rm -f wasi.wasm
"""

proc new*(args: seq[string]):int =
  ## Creates a new Nim project
  # ───────────────────────────────────────────────────────────────────────────────
  # コマンドライン引数チェック
  if args.len < 1:
    stderr.writeLine("Error: Define a project name.")
    quit(1)
  let projectName = args[0].replace(" ", "_").replace("-", "_")
  let projectPath = getCurrentDir() / projectName

  # ───────────────────────────────────────────────────────────────────────────────
  # 共通変数
  const
    frameworks = @["SvelteKit", "React", "Vue", "Vanilla JS", "No JS template", "None"]
    features   = @["Internet Identity", "Bitcoin (Regtest)", "Frontend tests"]

  # ───────────────────────────────────────────────────────────────────────────────
  # 初期化
  illwillInit(fullscreen = false)
  # defer: illwillDeinit()

  let termW = terminalWidth()
  let termH = terminalHeight()
  var tb = newTerminalBuffer(termW, termH)

  # ───────────────────────────────────────────────────────────────────────────────
  # ステップ1: フレームワーク選択
  var idxFW = 0
  while true:
    tb.clear()
    tb.write(2, 2, "? Select a frontend framework:")
    for i, fw in frameworks:
      if i == idxFW:
        tb.write(2, 4 + i, "> " & fw)
      else:
        tb.write(2, 4 + i, "  " & fw)
    tb.display()
    case getKey()
    of Key.Up:
      if idxFW > 0: dec idxFW
    of Key.Down:
      if idxFW < frameworks.len - 1: inc idxFW
    of Key.Enter:
      break
    else:
      discard

  let chosenFW = frameworks[idxFW]

  # ───────────────────────────────────────────────────────────────────────────────
  # ステップ2: 追加機能選択
  var selectedFeats = newSeq[bool](features.len)
  var idxFeat = 0

  while true:
    tb.clear()
    tb.write(2, 2, "? Add extra features (space to select, enter to confirm)")
    var row = 4
    # 各機能を表示（Frontend tests は条件付き）
    for i, feat in features:
      if feat == "Frontend tests" and chosenFW notin @["SvelteKit", "React", "Vue", "Vanilla JS"]:
        continue
      let mark = if selectedFeats[i]: "✓" else: " "
      if i == idxFeat:
        tb.write(2, row, "> " & mark & " " & feat)
      else:
        tb.write(2, row, "  " & mark & " " & feat)
      inc row

    tb.display()
    let key = getKey()
    case key
    of Key.Up:
      # 上に移動（存在しない行はスキップ）
      var newIdx = idxFeat - 1
      while newIdx >= 0:
        if not (features[newIdx] == "Frontend tests" and chosenFW notin @["SvelteKit", "React", "Vue"]):
          idxFeat = newIdx; break
        dec newIdx
    of Key.Down:
      # 下に移動
      var newIdx = idxFeat + 1
      while newIdx < features.len:
        if not (features[newIdx] == "Frontend tests" and chosenFW notin @["SvelteKit", "React", "Vue"]):
          idxFeat = newIdx; break
        inc newIdx
    of Key.Space:
      # チェック／アンチェック
      if not (features[idxFeat] == "Frontend tests" and chosenFW notin @["SvelteKit", "React", "Vue"]):
        selectedFeats[idxFeat] = not selectedFeats[idxFeat]
    of Key.Enter:
      break
    else:
      discard

  illwillDeinit()    # 画面制御を元に戻す
  # ───────────────────────────────────────────────────────────────────────────────

  let framework = (
    proc():string =
      case chosenFW
      of "SvelteKit": return "sveltekit"
      of "React": return "react"
      of "Vue": return "vue"
      of "Vanilla JS": return "vanilla"
      of "No JS template": return "simple-assets"
      of "None": return "none"
  )()
  var selectedFeatsList = newSeq[string]()
  for i, feat in features:
    if selectedFeats[i]:
      case feat
      of "Internet Identity":
        selectedFeatsList.add("internet-identity")
      of "Bitcoin (Regtest)":
        selectedFeatsList.add("bitcoin")
      of "Frontend tests":
        selectedFeatsList.add("frontend-tests")
  let selectedFeatsListStr = 
    if selectedFeatsList.len > 0:
      "--extras " & selectedFeatsList.join(" --extras ")
    else:
      ""

  let command = &"dfx new {projectName} --type motoko --frontend {framework} {selectedFeatsListStr}"
  let (output, exitCode) = execCmdEx(command)
  if exitCode != 0:
    echo "Error: ", output
    return 1

  removeFile(getCurrentDir() / projectName / &"src/{projectName}_backend/main.mo")
  writeFile(getCurrentDir() / projectName / &"src/{projectName}_backend/config.nims", configContent)
  writeFile(getCurrentDir() / projectName / &"src/{projectName}_backend/main.nim", mainCode)
  writeFile(getCurrentDir() / projectName / &"{projectName}.did", didContent)
  writeFile(getCurrentDir() / projectName / &"build.sh", buildContent(projectName))
  discard execCmd("chmod +x " & getCurrentDir() / projectName / &"build.sh")

  # replace dfx.json
  let dfxJson = readFile(getCurrentDir() / projectName / "dfx.json").parseJson()
  dfxJson["canisters"][&"{projectName}_backend"] = %*{
    "candid": &"{projectName}.did",
    "package": &"{projectName}_backend",
    "build": "build.sh",
    "main": &"src/{projectName}_backend/main.nim",
    "wasm": "main.wasm",
    "type": "custom",
    "metadata": [
      {
        "name": "candid:service"
      }
    ]
  }
  dfxJson["defaults"]["replica"] = %*{
    "subnet_type": "system"
  }
  dfxJson["networks"] = %*{
    "local": {
      "bind": "127.0.0.1:4943",
      "type": "ephemeral"
    }
  }
  writeFile(projectPath / "dfx.json", dfxJson.pretty())
