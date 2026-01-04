discard """
  cmd: "nim c --skipUserCfg $file"
"""
# nim c -r --skipUserCfg test_run_solidity.nim

import std/unittest
import std/os
import std/strutils
import std/json
import std/httpclient

const
  anvilRpc = "http://anvil:8545"
  broadcastPath = "/application/solidity/broadcast/deployCounter.s.sol/31337/run-latest.json"

proc rpcCall(methodName: string, params: JsonNode): JsonNode =
  var client = newHttpClient()
  client.headers = newHttpHeaders({"Content-Type": "application/json"})
  let payload = %*{
    "jsonrpc": "2.0",
    "id": 1,
    "method": methodName,
    "params": params
  }
  let resp = client.postContent(anvilRpc, $payload)
  result = parseJson(resp)

proc ethGetCode(address: string): string =
  let res = rpcCall("eth_getCode", %*[address, "latest"])
  if res.hasKey("result"): res["result"].getStr() else: ""

proc readCounterAddressFromBroadcast(path: string): string =
  if not fileExists(path): return ""
  let j = parseFile(path)
  if not j.hasKey("transactions"): return ""
  var address = ""
  for t in j["transactions"].items:
    if t.hasKey("contractName") and t["contractName"].getStr() == "Counter":
      if t.hasKey("contractAddress"):
        address = t["contractAddress"].getStr()
  return address

suite "solidity deploy":
  test "deploy Counter via deployCounter.sh and verify on anvil":
    # 1) (Optional) Check Anvil is reachable
    var reachable = false
    try:
      let res = rpcCall("eth_chainId", newJArray())
      reachable = res.hasKey("result")
    except CatchableError:
      reachable = false
    check reachable

    # 2) Check if contract is already deployed at known address
    const knownContractAddr = "0x5FbDB2315678afecb367f032d93F642f64180aa3"
    var contractAddr = ""
    let existingCode = ethGetCode(knownContractAddr)
    
    if existingCode.len > 2 and existingCode != "0x":
      # Contract already exists at known address
      echo "Counter already deployed at: ", knownContractAddr
      contractAddr = knownContractAddr
    else:
      # Contract not found, need to deploy
      echo "Counter not found at known address, deploying..."
      let rc = execShellCmd("cd /application/solidity/script/Counter && ./deployCounter.sh")
      check rc == 0
      
      # 3) Read latest deployed address from broadcast artifact
      contractAddr = readCounterAddressFromBroadcast(broadcastPath)
      echo "Counter deployed at: ", contractAddr
    
    # 4) Verify we have a valid contract address
    check contractAddr.len == 42 and contractAddr.startsWith("0x")

    # 5) Confirm the code exists at the address
    let code = ethGetCode(contractAddr)
    echo "eth_getCode: ", code
    check code.len > 2 and code != "0x"
