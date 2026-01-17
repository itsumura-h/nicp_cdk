import ./wasm_build

proc productionBuild*(): int =
  ## Build WASM only with -d:release (production)
  compileWasm(release = true)
