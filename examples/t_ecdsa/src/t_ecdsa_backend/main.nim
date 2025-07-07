import ../../../../src/nicp_cdk
import ./controller

proc getNewPublicKey*() {.update.} = discard controller.getNewPublicKey()
proc getPublicKey*() {.query.} = controller.getPublicKey()
proc signWithEcdsa*() {.update.} = discard controller.signWithEcdsa()
proc verifyWithEcdsa*() {.update.} = discard controller.verifyWithEcdsa()
proc getEvmAddress*() {.query.} = controller.getEvmAddress()