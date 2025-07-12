import ../../../../src/nicp_cdk
import ./controller

proc getNewPublicKey*() {.update.} = discard controller.getNewPublicKey()
proc getPublicKey*() {.query.} = controller.getPublicKey()
proc signWithEcdsa*() {.update.} = discard controller.signWithEcdsa()
proc verifyWithEcdsa*() {.update.} = controller.verifyWithEcdsa()
proc getEvmAddress*() {.query.} = controller.getEvmAddress()
# proc signWithEvm*() {.update.} = discard controller.signWithEvm()
# proc verifyEvm*() {.update.} = controller.verifyEvm()
# proc testSecp256k1*() {.query.} = controller.testSecp256k1()
