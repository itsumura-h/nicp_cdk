import ./wasm_build

proc developmentBuild*(): int =
  ## Build WASM only (no dfx create/install)
  compileWasm(release = false)
