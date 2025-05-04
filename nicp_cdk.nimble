# Package

version       = "0.1.0"
author        = "@dumblepytech1 as 'medy'"
description   = "Internet Computer CDK for Nim"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim", "h"]
bin           = @["cli/ndfx"]
backend       = "c"
skipDirs      = @["src/cli"]
binDir        = "src/bin"


# Dependencies

requires "nim >= 2.2.2"

requires "cligen >= 1.8.3"
requires "illwill >= 0.4.1"
requires "base32 >= 0.1.3"
