# Generate OTEL_INSTRUMENTATION_METHODS_INCLUDE for a JVM project so the OpenTelemetry
# Java agent adds method-level spans on the app's OWN business classes — without
# touching app code. Reads compiled classes (exact method names), prints the include
# string to stdout, or nothing if there's no build output / no javap / no matches.
#
# build/classes/java/main holds only the app's classes (deps live in jars), so we
# scan it directly. A class is "business logic" if its constant pool references a
# Spring stereotype, spring-grpc @GrpcService, or a generated gRPC *ImplBase.
#
# Scoped on purpose: spanning every method (getters, mappers, lambdas) buries the
# trace and adds overhead. Public methods only; accessors/synthetics filtered out.

root="${1:-$PWD}"

classdir=""
for d in "$root/build/classes/java/main" "$root/target/classes"; do
  if [ -d "$d" ]; then
    classdir="$d"
    break
  fi
done
[ -n "$classdir" ] || exit 0
command -v javap >/dev/null 2>&1 || exit 0

markerfile="$(mktemp)"
trap 'rm -f "$markerfile"' EXIT
cat >"$markerfile" <<'EOF'
org/springframework/stereotype/Service
org/springframework/stereotype/Component
org/springframework/stereotype/Repository
org/springframework/stereotype/Controller
org/springframework/web/bind/annotation/RestController
org/springframework/grpc/server/service/GrpcService
ImplBase
EOF

# Object / synthetic method names always skipped. Bean accessors are dropped by
# arity below, not by name — a get*/is* WITH params (e.g. getBillingState(req)) is
# a real operation, only no-arg get*()/is*() and single-arg set*() are accessors.
skip_name_re='^(equals|hashCode|toString|clone|finalize|main)$|\$'

entries=""
n_classes=0
n_methods=0

while IFS= read -r -d '' cf; do
  base="${cf##*/}"
  case "$base" in *'$'*) continue ;; esac # inner/anon/lambda class
  if ! LC_ALL=C grep -qaF -f "$markerfile" "$cf"; then continue; fi
  rel="${cf#"$classdir"/}"
  fqcn="${rel%.class}"
  fqcn="${fqcn//\//.}"
  simple="${fqcn##*.}"
  case "$simple" in *Grpc) continue ;; esac # generated gRPC stub class, not the impl

  methods=""
  while IFS= read -r line; do
    name="$(printf '%s' "$line" | sed -E 's/\(.*//; s/.*[ .<]([A-Za-z_$][A-Za-z0-9_$]*)$/\1/')"
    [ -n "$name" ] || continue
    [ "$name" = "$simple" ] && continue # constructor
    if printf '%s' "$name" | grep -qE "$skip_name_re"; then continue; fi
    # args = text between the first ( and its ); empty means a no-arg method
    args="$(printf '%s' "$line" | sed -E 's/^[^(]*\(//; s/\).*$//')"
    case "$name" in
    get[A-Z]* | is[A-Z]*) [ -z "$args" ] && continue ;;              # no-arg getter
    set[A-Z]*) case "$args" in "" | *,*) : ;; *) continue ;; esac ;; # single-arg setter
    esac
    case ",$methods," in *",$name,"*) continue ;; esac # dedupe overloads
    methods="${methods:+$methods,}$name"
  done < <(javap -cp "$classdir" "$fqcn" 2>/dev/null | grep -E '^  public .*\(' || true)

  [ -n "$methods" ] || continue
  entries="${entries:+$entries;}${fqcn}[${methods}]"
  n_classes=$((n_classes + 1))
  n_methods=$((n_methods + $(printf '%s' "$methods" | awk -F, '{print NF}')))
done < <(find "$classdir" -name '*.class' -print0)

[ -n "$entries" ] || exit 0
printf 'otel-dev: tracing %d methods across %d business classes\n' "$n_methods" "$n_classes" >&2
printf '%s' "$entries"
