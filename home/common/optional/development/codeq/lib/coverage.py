"""Per-package and least-covered-class summary from one or more JaCoCo XML reports."""

import collections
import sys
import xml.etree.ElementTree as ET

KINDS = ("LINE", "BRANCH", "METHOD")


def counters(el):
    out = {}
    for c in el.findall("counter"):
        out[c.get("type")] = (int(c.get("covered")), int(c.get("missed")) + int(c.get("covered")))
    return out


def pct(pair):
    covered, total = pair
    return f"{100 * covered / total:5.1f}%" if total else "   n/a"


def main(paths) -> int:
    pkgs = collections.defaultdict(lambda: collections.Counter())
    classes = []
    for path in paths:
        root = ET.parse(path).getroot()
        for p in root.findall("package"):
            for kind, (cov, tot) in counters(p).items():
                pkgs[p.get("name").replace("/", ".")][kind + "_c"] += cov
                pkgs[p.get("name").replace("/", ".")][kind + "_t"] += tot
            for c in p.findall("class"):
                cov, tot = counters(c).get("LINE", (0, 0))
                if tot >= 10:
                    classes.append((cov / tot, tot - cov, c.get("name").replace("/", ".")))

    total = collections.Counter()
    print(f"{'package':50}{'line':>8}{'branch':>8}{'method':>8}")
    for name in sorted(pkgs):
        c = pkgs[name]
        total.update(c)
        print(f"{name:50}" + "".join(f"{pct((c[k + '_c'], c[k + '_t'])):>8}" for k in KINDS))
    print(f"{'TOTAL':50}" + "".join(f"{pct((total[k + '_c'], total[k + '_t'])):>8}" for k in KINDS))

    print("\nLeast-covered classes (>= 10 lines):")
    for ratio, missed, name in sorted(classes)[:10]:
        print(f"  {100 * ratio:5.1f}%  {missed:4} lines missed  {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
