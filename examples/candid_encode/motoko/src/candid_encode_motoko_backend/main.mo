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

  public query func url() : async Text {
    return "https://api.exchange.coinbase.com/products/ICP-USD/candles?start=1682978460&end=1682978460&granularity=60";
  };

  public query func maxResponseBytes() : async ?Nat {
    return null;
  };

  public query func header() : async [HttpHeader] {
    let request_headers = [
      { name = "User-Agent"; value = "price-feed" },
    ];
    return request_headers;
  };

  public query func body() : async ?Blob {
    return null;
  };
};
