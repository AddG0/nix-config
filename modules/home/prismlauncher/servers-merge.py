#!/usr/bin/env python3
"""Sync declared Minecraft servers into an instance's servers.dat.

Usage: servers-merge.py <declared.json> <servers.dat> <state.json>

<declared.json> is a list of {"name", "address", "acceptTextures"?}. Declared
servers are ensured present, kept in sync with config, and un-hidden so they show
as pinned rather than Direct Connect history. This module manages only a subset:
<state.json> records the addresses it added last run, so a server dropped from
config is removed, while servers added in-game (never in the state file) survive.

servers.dat is uncompressed big-endian NBT. A minimal but complete NBT
read/writer lives here so the module needs no external dependency.
"""
import json
import os
import struct
import sys

(TAG_End, TAG_Byte, TAG_Short, TAG_Int, TAG_Long, TAG_Float, TAG_Double,
 TAG_Byte_Array, TAG_String, TAG_List, TAG_Compound,
 TAG_Int_Array, TAG_Long_Array) = range(13)


class Reader:
    def __init__(self, data):
        self.d, self.i = data, 0

    def take(self, n):
        b = self.d[self.i:self.i + n]
        if len(b) != n:
            raise EOFError("truncated NBT")
        self.i += n
        return b

    def num(self, fmt, n):
        return struct.unpack(">" + fmt, self.take(n))[0]

    def string(self):
        return self.take(self.num("H", 2)).decode("utf-8", "replace")

    def payload(self, tag):
        if tag == TAG_Byte:
            return self.num("b", 1)
        if tag == TAG_Short:
            return self.num("h", 2)
        if tag == TAG_Int:
            return self.num("i", 4)
        if tag == TAG_Long:
            return self.num("q", 8)
        if tag == TAG_Float:
            return self.num("f", 4)
        if tag == TAG_Double:
            return self.num("d", 8)
        if tag == TAG_Byte_Array:
            return ("barray", list(self.take(self.num("i", 4))))
        if tag == TAG_String:
            return self.string()
        if tag == TAG_List:
            et, n = self.num("B", 1), self.num("i", 4)
            return ("list", et, [self.payload(et) for _ in range(n)])
        if tag == TAG_Compound:
            out = []
            while True:
                t = self.num("B", 1)
                if t == TAG_End:
                    return ("compound", out)
                out.append((t, self.string(), self.payload(t)))
        if tag == TAG_Int_Array:
            return ("iarray", [self.num("i", 4) for _ in range(self.num("i", 4))])
        if tag == TAG_Long_Array:
            return ("larray", [self.num("q", 8) for _ in range(self.num("i", 4))])
        raise ValueError(f"unknown NBT tag {tag}")


class Writer:
    def __init__(self):
        self.buf = bytearray()

    def num(self, fmt, v):
        self.buf += struct.pack(">" + fmt, v)

    def string(self, s):
        b = s.encode("utf-8")
        self.num("H", len(b))
        self.buf += b

    def payload(self, tag, val):
        if tag == TAG_Byte:
            self.num("b", val)
        elif tag == TAG_Short:
            self.num("h", val)
        elif tag == TAG_Int:
            self.num("i", val)
        elif tag == TAG_Long:
            self.num("q", val)
        elif tag == TAG_Float:
            self.num("f", val)
        elif tag == TAG_Double:
            self.num("d", val)
        elif tag == TAG_Byte_Array:
            self.num("i", len(val[1]))
            self.buf += bytes(b & 0xFF for b in val[1])
        elif tag == TAG_String:
            self.string(val)
        elif tag == TAG_List:
            _, et, items = val
            self.num("B", et)
            self.num("i", len(items))
            for it in items:
                self.payload(et, it)
        elif tag == TAG_Compound:
            for t, nm, v in val[1]:
                self.num("B", t)
                self.string(nm)
                self.payload(t, v)
            self.num("B", TAG_End)
        elif tag == TAG_Int_Array:
            self.num("i", len(val[1]))
            for x in val[1]:
                self.num("i", x)
        elif tag == TAG_Long_Array:
            self.num("i", len(val[1]))
            for x in val[1]:
                self.num("q", x)
        else:
            raise ValueError(f"unknown NBT tag {tag}")


def load_root(path):
    try:
        with open(path, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        data = b""
    if not data:
        return ("compound", [])
    r = Reader(data)
    if r.num("B", 1) != TAG_Compound:
        return ("compound", [])
    r.string()  # root name, conventionally ""
    return r.payload(TAG_Compound)


def field(comp, key):
    for i, (_, nm, _) in enumerate(comp[1]):
        if nm == key:
            return i
    return None


def set_field(comp, tag, key, value):
    i = field(comp, key)
    entry = (tag, key, value)
    if i is None:
        comp[1].append(entry)
    else:
        comp[1][i] = entry


def del_field(comp, key):
    comp[1][:] = [e for e in comp[1] if e[1] != key]


def ip_of(comp):
    i = field(comp, "ip")
    return comp[1][i][2] if i is not None else None


def main():
    declared = json.load(open(sys.argv[1]))
    dat_path = sys.argv[2]
    state_path = sys.argv[3]
    root = load_root(dat_path)

    # Normalize the servers entry to List<Compound>: an empty list may carry a
    # TAG_End element type we can't append compounds to.
    entries = root[1]
    idx = field(root, "servers")
    if idx is not None and entries[idx][0] == TAG_List:
        items = entries[idx][2][2]
    else:
        items = []
    entries[:] = [e for e in entries if e[1] != "servers"]
    entries.insert(0, (TAG_List, "servers", ("list", TAG_Compound, items)))

    declared_addrs = []
    for s in declared:
        if s["address"] not in declared_addrs:
            declared_addrs.append(s["address"])

    try:
        prev_managed = json.load(open(state_path))
    except (FileNotFoundError, ValueError):
        prev_managed = []

    # Drop entries this module added before but that are no longer declared.
    # In-game additions were never in prev_managed, so they are left alone.
    stale = set(prev_managed) - set(declared_addrs)
    items[:] = [it for it in items if it[0] != "compound" or ip_of(it) not in stale]

    by_ip = {ip_of(it): it for it in items if it[0] == "compound"}
    for s in declared:
        comp = by_ip.get(s["address"])
        if comp is None:
            comp = ("compound", [])
            set_field(comp, TAG_String, "ip", s["address"])
            items.append(comp)
            by_ip[s["address"]] = comp
        set_field(comp, TAG_String, "name", s["name"])
        del_field(comp, "hidden")  # promote to a pinned server
        if s.get("acceptTextures") is not None:
            set_field(comp, TAG_Byte, "acceptTextures", 1 if s["acceptTextures"] else 0)

    w = Writer()
    w.num("B", TAG_Compound)
    w.string("")
    w.payload(TAG_Compound, root)
    with open(dat_path, "wb") as f:
        f.write(bytes(w.buf))

    if declared_addrs:
        with open(state_path, "w") as f:
            json.dump(declared_addrs, f)
    elif os.path.exists(state_path):
        os.remove(state_path)


if __name__ == "__main__":
    main()
