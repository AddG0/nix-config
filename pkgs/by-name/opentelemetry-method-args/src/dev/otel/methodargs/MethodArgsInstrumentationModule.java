package dev.otel.methodargs;

import static java.util.Collections.singletonList;

import io.opentelemetry.javaagent.extension.instrumentation.InstrumentationModule;
import io.opentelemetry.javaagent.extension.instrumentation.TypeInstrumentation;
import java.util.List;

public class MethodArgsInstrumentationModule extends InstrumentationModule {

  public MethodArgsInstrumentationModule() {
    super("otel-dev-method-args");
  }

  @Override
  public List<TypeInstrumentation> typeInstrumentations() {
    return singletonList(new MethodArgsTypeInstrumentation());
  }

  // After the library instrumentations, so our method spans nest under gRPC/HTTP.
  @Override
  public int order() {
    return 100;
  }
}
