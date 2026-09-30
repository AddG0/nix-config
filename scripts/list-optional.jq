# Input: {leaves: {"<tree>.<path>": storePath}, suites: {<suite>: {<nixos|home>: [storePath]}}}
# Args: $filter (prefix), $color ("1" to colour).
def esc($c): if $color == "1" then "\u001b[\($c)m" else "" end;
def paint($c): esc($c) + . + esc("0");
def pad($w): . + (" " * ([$w - length, 1] | max));
def parent: split(".")[:-1] | join(".");
def leaf: split(".") | last;
# Longest shared namespace of dotted names (never the whole name).
def sharedNs:
  map(split(".")) as $a
  | reduce range(0; ($a | map(length) | min) - 1) as $i ({p: [], ok: true};
      if .ok and ($a | map(.[$i]) | unique | length) == 1 then .p += [$a[0][$i]] else .ok = false end)
  | .p | join(".");

.leaves as $leaves
| ($leaves | to_entries | map({key: .value, value: .key}) | from_entries) as $name
| ([.suites | to_entries[] | .key as $s | .value | to_entries[] | .value[] | {p: ., s: $s}]
   | group_by(.p) | map({key: .[0].p, value: (map(.s) | unique)}) | from_entries) as $in
| ($leaves | to_entries | map(select(.key | startswith($filter)))) as $shown
| ("MODULES" | paint("1")) + ("   import as lib.custom.optional.<path>" | paint("2")),
  ("● " | paint("32")) + "in a suite   " + ("○ " | paint("33")) + "add-on (import it yourself)",
  ($shown | group_by(.key | parent) | .[]
   | (.[0].key | parent) as $ns
   | (map(select($in[.value])) | length) as $inSuites
   | "",
     (($ns | parent | if . == "" then "" else . + "." end | paint("2")) + ($ns | leaf | paint("1;36"))
       + ("   \($inSuites) in suites · \(length - $inSuites) add-on\(if length - $inSuites == 1 then "" else "s" end)" | paint("2"))),
     (sort_by(.key)[]
      | if $in[.value]
        then "  " + ("●" | paint("32")) + " " + (.key | leaf | pad(28)) + ($in[.value] | join(", ") | paint("2"))
        else "  " + ("○" | paint("33")) + " " + (.key | leaf)
        end)),
  "",
  ("SUITES" | paint("1")) + ("   host: lib.custom.useSuite lib.custom.suites.<name> · home: lib.custom.suites.<name>.home" | paint("2")),
  (.suites | to_entries[]
   | select($filter == "" or ([.value[][] | $name[.] // "" | startswith($filter)] | any))
   | "",
     (.key | paint("1;35")),
     (.value | to_entries[]
      | .key as $half
      | [.value[] | $name[.] // .] as $members
      | ($members | sharedNs) as $ns
      | "  " + ($half | pad(6) | paint(if $half == "nixos" then "34" else "32" end))
        + (if $ns == "" then "" else ($ns + " › " | paint("2")) end)
        + ($members | map(ltrimstr($ns) | ltrimstr(".")) | join("  "))))
