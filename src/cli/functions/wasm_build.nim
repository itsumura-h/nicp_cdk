import std/os
import std/osproc
import std/strutils

proc removeByGlob(pattern: string) =
  for path in walkFiles(pattern):
    removeFile(path)

proc resolveProjectName(projectDir: string): string =
  result = splitPath(projectDir).tail

proc resolveMainPath(projectDir: string): string =
  let projectName = resolveProjectName(projectDir)
  result = projectDir / "src" / (projectName & "_backend") / "main.nim"

proc compileWasm*(release: bool, wasiTmp = "wasi.wasm"): int =
  let projectDir = getCurrentDir()
  let dfxJsonPath = projectDir / "dfx.json"
  if not fileExists(dfxJsonPath):
    stderr.writeLine("Error: dfx.json not found in current directory.")
    return 1

  let mainPath = resolveMainPath(projectDir)
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

  return 0
