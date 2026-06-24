// Zero-code OpenTelemetry CLIENT instrumentation for Node's core http2 module.
// The standard auto-instrumentations cover http/https/undici/grpc-js but NOT raw
// http2 clients, which ConnectRPC's gRPC transport uses (@connectrpc/connect-node
// calls http2.connect) — so without this a trace dead-ends at the first ConnectRPC
// hop, no traceparent injected, and the downstream service starts a new trace.
//
// register.js requires this after the SDK, so the global tracer/W3C propagator
// exist. require('http2') and require('node:http2') share one cached module object,
// so patching connect once covers both.
const http2 = require("node:http2");
const {
  context,
  trace,
  propagation,
  SpanKind,
  SpanStatusCode,
} = require("@opentelemetry/api");

const tracer = trace.getTracer("otel-dev-http2-client", "1.0.0");
const PATCHED = Symbol.for("otel-dev.http2.request.patched");

function patchSessionRequest(session) {
  if (!session || session[PATCHED]) return;
  const original = session.request;
  if (typeof original !== "function") return;
  session[PATCHED] = true;

  session.request = function request(headers, options) {
    headers = headers || {};
    const method = headers[":method"] || "POST";
    const authority = headers[":authority"] || "";
    const path = headers[":path"] || "";

    const span = tracer.startSpan(`${method} ${path || authority}`.trim(), {
      kind: SpanKind.CLIENT,
      attributes: {
        "http.request.method": method,
        "server.address": authority.replace(/^https?:\/\//, ""),
        "url.path": path,
        "network.protocol.name": "http",
        "network.protocol.version": "2",
      },
    });
    const ctx = trace.setSpan(context.active(), span);

    propagation.inject(ctx, headers, {
      set: (carrier, key, value) => {
        carrier[key] = value;
      },
    });

    let stream;
    try {
      stream = context.with(ctx, () => original.call(this, headers, options));
    } catch (err) {
      span.recordException(err);
      span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
      span.end();
      throw err;
    }

    let ended = false;
    const end = () => {
      if (!ended) {
        ended = true;
        span.end();
      }
    };
    const recordGrpcStatus = (h) => {
      const gs = h && h["grpc-status"];
      if (gs != null) {
        const code = Number(gs);
        span.setAttribute("rpc.grpc.status_code", code);
        if (code !== 0) span.setStatus({ code: SpanStatusCode.ERROR });
      }
    };

    stream.once("response", (resp) => {
      const status = resp[":status"];
      if (status != null) span.setAttribute("http.response.status_code", status);
      recordGrpcStatus(resp); // unary gRPC errors can arrive as header trailers
    });
    stream.once("trailers", recordGrpcStatus);
    stream.once("error", (err) => {
      span.recordException(err);
      span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
      end();
    });
    stream.once("close", end);

    return stream;
  };
}

const originalConnect = http2.connect;
http2.connect = function connect(...args) {
  const session = originalConnect.apply(this, args);
  patchSessionRequest(session);
  return session;
};
