#!/usr/bin/env python3
"""Validate generated Agent Skill / ChatGPT Skill entrypoints."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

try:
    import yaml
except ImportError as exc:  # pragma: no cover
    raise SystemExit("PyYAML is required") from exc

PORTABLE_KEYS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
CHATGPT_KEYS = {"name", "description"}


def parse_frontmatter(text: str):
    m = re.match(r"^---\n(.*?)\n---\n?", text, re.S)
    if not m:
        raise ValueError("Missing or invalid YAML frontmatter")
    data = yaml.safe_load(m.group(1))
    if not isinstance(data, dict):
        raise ValueError("Frontmatter must be a mapping")
    return data, text[m.end():]


def validate(path: Path, chatgpt: bool) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    skill_md = path / "SKILL.md" if path.is_dir() else path
    if not skill_md.exists():
        return [f"SKILL.md not found: {skill_md}"], warnings

    text = skill_md.read_text(encoding="utf-8")
    try:
        fm, body = parse_frontmatter(text)
    except Exception as exc:
        return [str(exc)], warnings

    allowed = CHATGPT_KEYS if chatgpt else PORTABLE_KEYS
    extra = set(fm) - allowed
    if extra:
        errors.append(f"Unexpected frontmatter keys: {', '.join(sorted(extra))}")

    name = fm.get("name")
    desc = fm.get("description")
    if not isinstance(name, str) or not name.strip():
        errors.append("name must be a non-empty string")
    elif not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name.strip()):
        errors.append("name must be lowercase hyphen-case")
    if not isinstance(desc, str) or not desc.strip():
        errors.append("description must be a non-empty string")
    else:
        desc = desc.strip()
        if len(desc) > 1024:
            errors.append("description exceeds 1024 characters")
        if not re.search(r"\b(use when|when|for)\b", desc, re.I):
            warnings.append("description may not clearly state activation context (what + when)")

    body_lines = body.splitlines()
    if len(body_lines) > 500:
        warnings.append(f"SKILL.md body is {len(body_lines)} lines; prefer under 500 and move detail to references")

    root = skill_md.parent
    refs = root / "references"
    if refs.exists():
        for md in refs.glob("*.md"):
            try:
                lines = md.read_text(encoding="utf-8").splitlines()
            except OSError:
                continue
            if len(lines) > 100:
                head = "\n".join(lines[:40]).lower()
                if "contents" not in head and "table of contents" not in head:
                    warnings.append(f"Long reference lacks an early contents section: {md.name}")

    if chatgpt and not (root / "agents" / "openai.yaml").exists():
        warnings.append("ChatGPT mode: agents/openai.yaml is missing")

    return errors, warnings


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("skill")
    ap.add_argument("--chatgpt", action="store_true")
    args = ap.parse_args()
    errors, warnings = validate(Path(args.skill), args.chatgpt)
    print("VALID" if not errors else "INVALID")
    for e in errors:
        print(f"ERROR: {e}")
    for w in warnings:
        print(f"WARN: {w}")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
