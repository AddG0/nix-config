#!/usr/bin/env bash
# Run any dev command with OpenTelemetry auto-instrumentation, pointed at the
# local collector. Touches no repo files.
#
#   otel-dev pnpm dev
#   otel-dev ./gradlew bootRun
#
# Sets NODE_OPTIONS (Node), JAVA_TOOL_OPTIONS (JVM) and PYTHONPATH (Python) at
# once; a command in one stack ignores the others' vars, so one wrapper covers
# all three with no language detection.
#
# OTEL_NODE_BUNDLE, OTEL_JAVAAGENT_JAR and OTEL_PYTHON_* are injected by
# default.nix (Nix store paths), so this script stays a plain, shellcheck-able file.

if [ "$#" -eq 0 ]; then
  echo "usage: otel-dev <command> [args...]" >&2
  exit 1
fi

# Collector: local OTel collector forwards to the Grafana stack.
# http/protobuf to :4318 is honored by both the JS SDK and the Java agent.
export OTEL_EXPORTER_OTLP_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}"
export OTEL_EXPORTER_OTLP_PROTOCOL="${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf}"
export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-$(basename "$PWD")}"

# Ship all three signals. Traces/metrics default to otlp, but logs do not — so
# enable it explicitly. Captures structured-logger output (pino/winston/bunyan
# on Node; logback/log4j2 on the JVM), with trace context correlated in.
# Note: raw console.log / System.out.println go to stdout and are NOT captured.
export OTEL_TRACES_EXPORTER="${OTEL_TRACES_EXPORTER:-otlp}"
export OTEL_METRICS_EXPORTER="${OTEL_METRICS_EXPORTER:-otlp}"
export OTEL_LOGS_EXPORTER="${OTEL_LOGS_EXPORTER:-otlp}"

# Node: require the Nix-provided auto-instrumentation bundle. NODE_PATH lets the
# bundle's deps resolve without the repo depending on them; require-in-the-middle
# then patches the app's own modules (http, pg, ...) process-wide. The register.js
# entrypoint also adds http2 client tracing (ConnectRPC/gRPC transport), which the
# stock auto-instrumentations don't cover. A single --require (not two) because
# next/turbopack re-parses NODE_OPTIONS and mangles multiple --require flags.
export NODE_PATH="${OTEL_NODE_BUNDLE}${NODE_PATH:+:$NODE_PATH}"
export NODE_OPTIONS="--require ${OTEL_NODE_REGISTER}${NODE_OPTIONS:+ $NODE_OPTIONS}"

# JVM: the agent is loaded by the forked app JVM (and the Gradle daemon — run
# with --no-daemon if that noise is unwanted). The method-args extension adds a span
# per business method carrying its argument values (vs the stock methods.include,
# which has no way to capture args).
export JAVA_TOOL_OPTIONS="-javaagent:${OTEL_JAVAAGENT_JAR} -Dotel.javaagent.extensions=${OTEL_METHOD_ARGS_JAR}${JAVA_TOOL_OPTIONS:+ $JAVA_TOOL_OPTIONS}"

# Scope those per-method spans to the app's own business classes (Spring stereotypes,
# gRPC impls), derived from compiled classes — the agent only spans library
# boundaries otherwise. Respects a manual override; the generator no-ops for
# non-JVM/unbuilt projects, and its errors never abort the launch.
if [ -z "${OTEL_DEV_METHOD_ARGS_INCLUDE:-}" ]; then
  if _otel_methods="$("${OTEL_JAVA_METHODS_GEN}" "$PWD")"; then
    [ -n "$_otel_methods" ] && export OTEL_DEV_METHOD_ARGS_INCLUDE="$_otel_methods"
  fi
  unset _otel_methods
fi

# Python: replicate `opentelemetry-instrument` without the command wrapper. The
# auto_instrumentation dir holds a sitecustomize.py that boots the SDK on any
# interpreter start; the bundle's site-packages makes `opentelemetry` importable
# from the app's own venv. require-in-the-middle's Python analogue then patches
# installed libs (flask, django, requests, psycopg2, ...) in place.
# Caveat: the bundle is built for one CPython. Pure-Python OTel tolerates a
# different app interpreter, so force pure-Python protobuf to dodge a
# C-extension ABI mismatch on the OTLP/HTTP exporter.
export PYTHONPATH="${OTEL_PYTHON_AUTO}:${OTEL_PYTHON_SITE}${PYTHONPATH:+:$PYTHONPATH}"
export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION="${PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION:-python}"

exec "$@"
