"""Martin package metrics (Ca, Ce, I, A, D) from `jdeps -verbose:class` output plus `javap` declarations."""

import argparse
import collections
import os
import re
import sys


def package_of(cls: str, prefix: str) -> str:
    rest = cls[len(prefix):] if cls.startswith(prefix) else cls
    return rest.rsplit(".", 1)[0] if "." in rest else "(root)"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("deps")
    ap.add_argument("decls")
    ap.add_argument("outdir")
    ap.add_argument("--prefix", default="")
    ap.add_argument("--packages", help="file listing the packages declared in hand-written sources")
    args = ap.parse_args()

    # The project's own types come from javap; jdeps also reports every JDK/library edge.
    decls = []
    with open(args.decls) as f:
        for line in f:
            m = re.search(r"\b(class|interface|enum|record) (\S+)", line)
            if m and not m.group(2).endswith("package-info"):
                decls.append((m.group(1), m.group(2).split("<")[0], line))
    if args.packages:
        with open(args.packages) as f:
            source_pkgs = {line.strip() for line in f if line.strip()}
        decls = [d for d in decls if d[1].rsplit(".", 1)[0] in source_pkgs]
    own = {name for _, name, _ in decls}
    if not own:
        print("codeq: javap listed no classes", file=sys.stderr)
        return 1

    prefix = args.prefix or os.path.commonprefix(sorted(own))
    prefix = prefix[: prefix.rfind(".") + 1] if "." in prefix else ""

    edges = set()
    with open(args.deps) as f:
        for line in f:
            m = re.match(r"\s+(\S+)\s+->\s+(\S+)", line)
            if not m:
                continue
            a, b = (x.split("$")[0] for x in m.groups())
            if a != b and a in own and b in own and a.startswith(prefix) and b.startswith(prefix):
                edges.add((a, b))
    if not edges:
        print("codeq: no dependencies between the project's own classes", file=sys.stderr)
        return 1

    total, abstract = collections.Counter(), collections.Counter()
    for kind, name, line in decls:
        if not name.startswith(prefix):
            continue
        pkg = package_of(name, prefix)
        total[pkg] += 1
        if kind == "interface" or "abstract" in line.split(kind)[0]:
            abstract[pkg] += 1

    pkg_edges = collections.defaultdict(set)
    for a, b in edges:
        pa, pb = package_of(a, prefix), package_of(b, prefix)
        if pa != pb:
            pkg_edges[(pa, pb)].add((a, b))

    rows = []
    for p in sorted(set(total) | {p for e in pkg_edges for p in e}):
        ca = {a for (_, pb), s in pkg_edges.items() if pb == p for a, _ in s}
        ce = {b for (pa, _), s in pkg_edges.items() if pa == p for _, b in s}
        i = len(ce) / (len(ca) + len(ce)) if ca or ce else 0.0
        a = abstract[p] / total[p] if total[p] else 0.0
        rows.append((p, total[p], len(ca), len(ce), i, a, abs(a + i - 1)))

    print(f"root package: {prefix.rstrip('.') or '(none)'}\n")
    print(f"{'package':34}{'types':>6}{'Ca':>5}{'Ce':>5}{'I':>6}{'A':>6}{'D':>6}  zone")
    for p, n, ca, ce, i, a, d in rows:
        zone = "pain: stable+concrete" if i < 0.3 and a < 0.3 and ca else "useless: abstract+unused" if i > 0.7 and a > 0.7 else ""
        print(f"{p:34}{n:>6}{ca:>5}{ce:>5}{i:6.2f}{a:6.2f}{d:6.2f}  {zone}")

    violations = [
        (pa, pb) for (pa, pb) in pkg_edges
        if pa.split(".")[0] != pb.split(".")[0]
        and next(r[4] for r in rows if r[0] == pa) < next(r[4] for r in rows if r[0] == pb)
    ]
    print("\nStable Dependencies Principle (arrows should point toward lower I):")
    for pa, pb in sorted(violations):
        print(f"  violation: {pa} -> {pb}")
    if not violations:
        print("  no violations between top-level packages")

    with open(os.path.join(args.outdir, "packages.dot"), "w") as f:
        f.write('digraph G {rankdir=LR; node[shape=box,style="rounded,filled",fillcolor="#eef3fb",fontname=Helvetica];\n')
        for p, _, ca, ce, i, _, _ in rows:
            f.write(f'"{p}" [label="{p}\\nCa={ca} Ce={ce} I={i:.2f}"];\n')
        for (pa, pb), s in pkg_edges.items():
            f.write(f'"{pa}" -> "{pb}" [label="{len(s)}",penwidth={1 + len(s) / 4:.1f}];\n')
        f.write("}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
