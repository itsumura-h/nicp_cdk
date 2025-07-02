import ./candid_types

# Definition of Service type
type Service* = object

# Constructor function for Service type
proc new*(_: type Service, principal: string): CandidRecord =
  ## Generates a CandidRecord of Service type from Principal ID
  newCandidService(principal) 
