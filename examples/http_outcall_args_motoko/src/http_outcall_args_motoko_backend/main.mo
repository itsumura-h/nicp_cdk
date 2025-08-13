import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";

actor {
  type HttpHeader = {
    name : Text;
    value : Text;
  };

  type HttpMethod = {
    #get; #post; #put; #delete; #head; #patch; #options;
  };

  type HttpResponsePayload = {
    status : Nat;
    headers : [HttpHeader];
    body : Blob;
  };

  type TransformArgs = {
    context : Blob;
    response : HttpResponsePayload;
  };

  type HttpRequestArgs = {
    url : Text;
    max_response_bytes : ?Nat;
    headers : [HttpHeader];
    body : ?Blob;
    method : HttpMethod;
    transform : ?{
      function : shared query (TransformArgs) -> async HttpResponsePayload;
      context : Blob;
    };
    is_replicated : ?Bool;
  };

  public query func httpRequestArgs() : async HttpRequestArgs {
    let ONE_MINUTE : Nat64 = 60;
    let start_timestamp : Nat64 = 1682978460; //May 1, 2023 22:01:00 GMT
    let host : Text = "api.exchange.coinbase.com";
    let url = "https://" # host # "/products/ICP-USD/candles?start=" # Nat64.toText(start_timestamp) # "&end=" # Nat64.toText(start_timestamp) # "&granularity=" # Nat64.toText(ONE_MINUTE);

    // 1.2 prepare headers for the system http_request call
    let request_headers = [
      { name = "User-Agent"; value = "price-feed" },
    ];

    let http_request : HttpRequestArgs = {
      url = url;
      max_response_bytes = null; //optional for request
      headers = request_headers;
      body = null; //optional for request
      method = #get;
      transform = null;
      // Toggle this flag to switch between replicated and non-replicated http outcalls.
      is_replicated = ?false;
    };

    return http_request;
  };
};
