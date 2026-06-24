package dev.otel.methodargs;

import static net.bytebuddy.matcher.ElementMatchers.isMethod;
import static net.bytebuddy.matcher.ElementMatchers.isPublic;
import static net.bytebuddy.matcher.ElementMatchers.namedOneOf;

import io.opentelemetry.javaagent.extension.instrumentation.TypeInstrumentation;
import io.opentelemetry.javaagent.extension.instrumentation.TypeTransformer;
import net.bytebuddy.description.type.TypeDescription;
import net.bytebuddy.matcher.ElementMatcher;

public class MethodArgsTypeInstrumentation implements TypeInstrumentation {

  @Override
  public ElementMatcher<TypeDescription> typeMatcher() {
    return namedOneOf(Config.classNames());
  }

  @Override
  public void transform(TypeTransformer transformer) {
    // A method is wrapped when its class is in the list AND its name is in the union
    // of configured names. That can over-match (a configured class's other method
    // sharing a name), but those are all business methods too, so extra spans here
    // are acceptable — and it keeps the advice free of any custom helper class.
    transformer.applyAdviceToMethod(
        isMethod().and(isPublic()).and(namedOneOf(Config.methodNames())),
        "dev.otel.methodargs.MethodArgsAdvice");
  }
}
