// Single --require entrypoint: the stock SDK plus our http2 client instrumentation.
// Combined into ONE require because next dev / turbopack re-parse NODE_OPTIONS and
// mangle multiple --require flags into a single bad specifier.
require("@opentelemetry/auto-instrumentations-node/register");
require("./http2-register.js");
