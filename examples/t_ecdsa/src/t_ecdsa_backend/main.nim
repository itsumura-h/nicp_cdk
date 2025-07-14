import ../../../../src/nicp_cdk
import ./controller

proc getNewPublicKey*() {.update.} = discard controller.getNewPublicKey()
proc getPublicKey*() {.query.} = controller.getPublicKey()
proc signWithEcdsa*() {.update.} = discard controller.signWithEcdsa()
proc verifyWithEcdsa*() {.update.} = controller.verifyWithEcdsa()
proc getEvmAddress*() {.query.} = controller.getEvmAddress()
proc signWithEthereum*() {.update.} = discard controller.signWithEthereum()
proc verifyWithEthereum*() {.update.} = controller.verifyWithEthereum()
# proc testSecp256k1*() {.query.} = controller.testSecp256k1()
