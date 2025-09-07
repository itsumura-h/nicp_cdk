import ./nicp_cdk/ic0/wasm; export wasm;
import ./nicp_cdk/message; export message;
import ./nicp_cdk/request; export request;
import ./nicp_cdk/reply; export reply;
import ./nicp_cdk/ic_types/ic_principal; export ic_principal;
import ./nicp_cdk/ic_types/ic_record; export ic_record;
import ./nicp_cdk/ic_types/ic_service; export ic_service;
import ./nicp_cdk/ic_types/ic_text; export ic_text;
import ./nicp_cdk/ic_types/ic_variant; export ic_variant;
import ./nicp_cdk/ic_types/candid_types; export candid_types;
import ./nicp_cdk/ic_types/ic_func; export ic_func;
import ./nicp_cdk/ic_types/candid_funcs; export candid_funcs;
import ./nicp_cdk/ic_api; export ic_api;
import ./nicp_cdk/async/ic_async; export ic_async;
import ./nicp_cdk/canisters/management_canister; export management_canister;

# Convenience re-exported helpers for function references
proc newQueryFunc*[T](methodName: string, args: seq[CandidType], returnType: typedesc[T]): IcFunc =
  ## Create a query func reference on the current canister
  ic_func.newQueryFunc(methodName, args, returnType)

proc newQueryFunc*[T](methodName: string, returnType: typedesc[T]): IcFunc =
  ## Create a query func reference on the current canister with no args
  ic_func.newQueryFunc(methodName, returnType)
