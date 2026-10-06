"""Summarise CK's class.csv / method.csv: distributions, hotspots, low-cohesion classes."""

import csv
import os
import statistics
import sys


def num(row, key):
    try:
        return float(row[key])
    except (KeyError, ValueError):
        return 0.0


def main(ckdir) -> int:
    rows = list(csv.DictReader(open(os.path.join(ckdir, "class.csv"))))
    methods = list(csv.DictReader(open(os.path.join(ckdir, "method.csv"))))
    if not rows:
        print("codeq: CK found no classes", file=sys.stderr)
        return 1
    short = lambda name: name.rsplit(".", 2)[-2] + "." + name.rsplit(".", 1)[-1] if name.count(".") > 1 else name

    print(f"{len(rows)} types\n\n{'metric':36}{'median':>8}{'p90':>8}{'max':>8}")
    for key, label in [
        ("cbo", "CBO  coupling between objects"),
        ("wmc", "WMC  weighted methods (complexity)"),
        ("rfc", "RFC  response for class"),
        ("lcom*", "LCOM* lack of cohesion (0 good)"),
        ("dit", "DIT  inheritance depth"),
        ("loc", "LOC  lines per type"),
    ]:
        vals = sorted(num(r, key) for r in rows)
        print(f"{label:36}{statistics.median(vals):8.2f}{vals[int(0.9 * (len(vals) - 1))]:8.2f}{vals[-1]:8.2f}")

    for key, label in [("wmc", "Top WMC"), ("cbo", "Top CBO"), ("rfc", "Top RFC")]:
        print(f"\n{label}:")
        for r in sorted(rows, key=lambda r: -num(r, key))[:6]:
            print(f"  {num(r, key):5.0f}  {short(r['class'])}")

    print("\nLow cohesion (LCOM* >= 0.8, >= 5 methods):")
    for r in sorted(rows, key=lambda r: -num(r, "lcom*")):
        if num(r, "lcom*") >= 0.8 and num(r, "totalMethodsQty") >= 5:
            print(f"  {num(r, 'lcom*'):.2f}  {short(r['class'])}  ({int(num(r, 'totalMethodsQty'))} methods)")

    print("\nMost complex methods:")
    for m in sorted(methods, key=lambda m: -num(m, "wmc"))[:8]:
        print(f"  {num(m, 'wmc'):4.0f}  {short(m['class'])}.{m['method'].split('/')[0]}  (loc {m['loc']})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
