import ../../../../../src/nicp_cdk
# import ../../../../src/nicp_cdk/canisters/management_canister
import ./controller

proc get_httpbin() {.update.} = discard controller.get_httpbin()
proc post_httpbin() {.update.} = discard controller.post_httpbin()
proc transform() {.query.} = controller.transform()
proc get_transform_funcion() {.query.} = controller.get_transform_funcion()
