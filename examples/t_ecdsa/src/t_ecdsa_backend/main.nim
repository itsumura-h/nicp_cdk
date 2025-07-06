import ../../../../src/nicp_cdk
import ./controller

proc getNewPublicKey*() {.update.} = discard controller.getNewPublicKey()
proc getPublicKey*() {.query.} = controller.getPublicKey()
proc signMessage*() {.update.} = discard controller.signMessage()
proc verify*() {.update.} = discard controller.verify()