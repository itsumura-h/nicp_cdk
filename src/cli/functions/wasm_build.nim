import std/os
import std/osproc
import std/strutils

proc removeByGlob(pattern: string) =
  for path in walkFiles(pattern):
    removeFile(path)

proc resolveProjectName(projectDir: string): string =
  for pattern in [projectDir / "*.nimble", projectDir / "*.did"]:
    for path in walkFiles(pattern):
      return splitFile(path).name
  return ""

proc resolveMainPath(projectDir: string, projectName: string): string =
  result = projectDir / "src" / (projectName & "_backend") / "main.nim"

proc compileWasm*(release: bool, wasiTmp = "wasi.wasm"): int =
  let projectDir = getCurrentDir()
  let dfxJsonPath = projectDir / "dfx.json"
  if not fileExists(dfxJsonPath):
    stderr.writeLine("Error: dfx.json not found in current directory.")
    return 1

  let projectName = resolveProjectName(projectDir)
  if projectName.len == 0:
    stderr.writeLine("Error: project name not found (.nimble or .did file not found in current directory).")
    return 1

  let mainPath = resolveMainPath(projectDir, projectName)
  if not fileExists(mainPath):
    stderr.writeLine("Error: main.nim not found at: " & mainPath)
    return 1

  removeByGlob("*.wasm")
  removeByGlob("*.wat")

  var defines: seq[string] = @[]
  if release:
    defines.add("-d:release")

  var nimCmd = "nim c"
  if defines.len > 0:
    nimCmd &= " " & defines.join(" ")
  nimCmd &= " -o:" & wasiTmp & " " & mainPath

  echo nimCmd
  let (nimOut, nimExit) = execCmdEx(nimCmd)
  if nimExit != 0:
    stderr.writeLine(nimOut)
    return nimExit

  let wasi2icCmd = "wasi2ic " & wasiTmp & " main.wasm"
  echo wasi2icCmd
  let (w2iOut, w2iExit) = execCmdEx(wasi2icCmd)
  if w2iExit != 0:
    stderr.writeLine(w2iOut)
    return w2iExit

  if fileExists(wasiTmp):
    removeFile(wasiTmp)

  # ic-wasm: optimize O3 (both debug and release)
  const icWasmTmp = "main_ic_wasm.wasm"
  let optimizeCmd = "ic-wasm main.wasm -o " & icWasmTmp & " optimize O3"
  echo optimizeCmd
  let (optOut, optExit) = execCmdEx(optimizeCmd)
  if optExit != 0:
    stderr.writeLine(optOut)
    return optExit
  moveFile(icWasmTmp, "main.wasm")

  # ic-wasm: shrink (release only)
  if release:
    let shrinkCmd = "ic-wasm main.wasm -o " & icWasmTmp & " shrink"
    echo shrinkCmd
    let (shrOut, shrExit) = execCmdEx(shrinkCmd)
    if shrExit != 0:
      stderr.writeLine(shrOut)
      return shrExit
    moveFile(icWasmTmp, "main.wasm")

  return 0
