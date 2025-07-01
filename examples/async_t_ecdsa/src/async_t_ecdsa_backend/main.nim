import ../../../../src/nicp_cdk
import ./controller

# ----------------------------------------------------------------------------
# IC に公開する update エントリポイント（返値なし）
# ----------------------------------------------------------------------------
proc getNewPublicKey*() {.update.} = discard controller.getNewPublicKey()
proc getPublicKey*() {.query.} = controller.getPublicKey()
