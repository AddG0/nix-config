package dev.otel.methodargs;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Parses OTEL_DEV_METHOD_ARGS_INCLUDE (the "fqcn[m1,m2];fqcn2[m3]" list otel-dev
 * generates) into the class/method names the matcher targets. Used only agent-side
 * (in the TypeInstrumentation), never from the inlined advice.
 */
final class Config {
  private static final Map<String, Set<String>> METHODS =
      parse(System.getenv("OTEL_DEV_METHOD_ARGS_INCLUDE"));

  private Config() {}

  static String[] classNames() {
    return METHODS.keySet().toArray(new String[0]);
  }

  static String[] methodNames() {
    Set<String> all = new HashSet<>();
    for (Set<String> m : METHODS.values()) {
      all.addAll(m);
    }
    return all.toArray(new String[0]);
  }

  private static Map<String, Set<String>> parse(String spec) {
    Map<String, Set<String>> out = new HashMap<>();
    if (spec == null || spec.isEmpty()) {
      return out;
    }
    for (String entry : spec.split(";")) {
      int open = entry.indexOf('[');
      int close = entry.lastIndexOf(']');
      if (open < 0 || close <= open) {
        continue;
      }
      String fqcn = entry.substring(0, open).trim();
      Set<String> methods = new HashSet<>();
      for (String m : entry.substring(open + 1, close).split(",")) {
        String name = m.trim();
        if (!name.isEmpty()) {
          methods.add(name);
        }
      }
      if (!fqcn.isEmpty() && !methods.isEmpty()) {
        out.put(fqcn, methods);
      }
    }
    return out;
  }
}
