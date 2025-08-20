import std/options
import ../../../../../src/nicp_cdk
import ../../../../../src/nicp_cdk/canisters/management_canister/http_outcall


proc url() {.query.} =
  reply("https://api.exchange.coinbase.com/products/ICP-USD/candles?start=1682978460&end=1682978460&granularity=60")


proc maxResponseBytes() {.query.} =
  reply(none(uint))


proc header() {.query.} =
  let request_headers = @[
    HttpHeader(name: "User-Agent", value: "price-feed"),
  ]
  reply(request_headers)


proc body() {.query.} =
  reply(none(seq[uint8]))


proc `method`() {.query.} =
  reply(HttpMethod.GET)


# proc transform() {.query.} =
#   reply(none(TransformArgs))