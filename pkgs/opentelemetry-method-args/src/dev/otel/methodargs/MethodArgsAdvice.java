package dev.otel.methodargs;

import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.context.Scope;
import net.bytebuddy.asm.Advice;

/**
 * Wraps a configured method in a span carrying its argument values. Inlined into the
 * instrumented class, so it must reference ONLY JDK + opentelemetry-api types (the
 * agent remaps those to its bootstrap copies); a reference to any custom class here
 * would need helper injection and fail with NoClassDefFoundError. Scoping lives in
 * the matcher (agent-side), not here.
 */
public class MethodArgsAdvice {

  @Advice.OnMethodEnter(suppress = Throwable.class)
  public static Object[] enter(
      @Advice.Origin("#t") String type,
      @Advice.Origin("#m") String method,
      @Advice.AllArguments Object[] args) {
    Span span =
        GlobalOpenTelemetry.getTracer("otel-dev.method-args")
            .spanBuilder(type.substring(type.lastIndexOf('.') + 1) + "." + method)
            .startSpan();
    span.setAttribute("code.namespace", type);
    span.setAttribute("code.function", method);
    if (args != null) {
      for (int i = 0; i < args.length; i++) {
        Object arg = args[i];
        String value;
        if (arg == null) {
          value = "null";
        } else {
          try {
            value = String.valueOf(arg);
          } catch (Throwable t) {
            value = "<unrenderable>";
          }
          value = value.replace('\n', ' ').trim();
          if (value.length() > 1024) {
            value = value.substring(0, 1024) + "…(+" + (value.length() - 1024) + ")";
          }
        }
        span.setAttribute("code.args." + i, value);
      }
    }
    return new Object[] {span, span.makeCurrent()};
  }

  @Advice.OnMethodExit(onThrowable = Throwable.class, suppress = Throwable.class)
  public static void exit(@Advice.Enter Object[] state, @Advice.Thrown Throwable thrown) {
    if (state == null) {
      return;
    }
    Span span = (Span) state[0];
    Scope scope = (Scope) state[1];
    if (thrown != null) {
      span.recordException(thrown);
      span.setStatus(StatusCode.ERROR);
    }
    scope.close();
    span.end();
  }
}
