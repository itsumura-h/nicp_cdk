import std/httpclient
import std/sequtils
import std/strutils
import std/strformat

proc ic0*():int =
  # download ic0.txt
  const ic0TextUrl = "https://raw.githubusercontent.com/dfinity/cdk-rs/refs/heads/main/ic0/ic0.txt"
  var ic0Text:string
  var client = newHttpClient()
  try:
    ic0Text = client.getContent(ic0TextUrl)
  finally:
    client.close()
  # echo ic0Text

  # 改行コードで分割して配列に
  let ic0NimProcLines = ic0Text.split(";").map(
    proc(line:string):string =
      let line = line.split(";")[0].strip()
      echo line
      let procName = line.split(" ")[0].split(".")[1]
      let procArgs = line.split("(")[1].split(")")[0]
      let responseType = line.split("->")[1].strip()
      return &"""proc {procName}({procArgs}):{responseType} = WASM_SYMBOL_IMPORTED("ic0", "{procName}")"""
  )
  echo ic0NimProcLines

  var ic0NimFile = """
import ./wasm


"""
