#!/usr/bin/env python3
"""Safely inspect a repository for code-assistant configuration context.

This script reports filenames, language counts, package managers, common project
commands, CI surfaces, and known assistant configuration surfaces. It avoids
reading secret files and never prints file contents except selected manifest
fields such as package.json scripts.
"""

from __future__ import annotations

import argparse
import json
import os
import re
from collections import Counter
from pathlib import Path
from typing import Any

IGNORED_DIRS = {
    ".git", ".hg", ".svn", "node_modules", "vendor", "dist", "build",
    ".next", ".turbo", ".cache", "coverage", "target", ".venv", "venv",
    "__pycache__", ".idea", ".vscode-test",
}

SECRET_NAME_RE = re.compile(
    r"(^|[._-])(secret|secrets|credential|credentials|token|tokens|password|passwd|private[_-]?key)([._-]|$)",
    re.I,
)

LANG_EXTENSIONS = {
    ".py": "Python", ".js": "JavaScript", ".jsx": "JavaScript/JSX",
    ".ts": "TypeScript", ".tsx": "TypeScript/TSX", ".java": "Java",
    ".kt": "Kotlin", ".kts": "Kotlin", ".go": "Go", ".rs": "Rust",
    ".rb": "Ruby", ".php": "PHP", ".cs": "C#", ".cpp": "C++",
    ".cc": "C++", ".cxx": "C++", ".c": "C", ".h": "C/C++ Header",
    ".hpp": "C++ Header", ".swift": "Swift", ".scala": "Scala",
    ".sh": "Shell", ".bash": "Shell", ".zsh": "Shell", ".sql": "SQL",
    ".ex": "Elixir", ".exs": "Elixir", ".lua": "Lua", ".dart": "Dart",
}

ASSISTANT_SURFACES = [
    "CLAUDE.md", "AGENTS.md", "GEMINI.md", ".cursorrules",
    ".github/copilot-instructions.md", ".claude/settings.json",
    ".claude/settings.local.json", ".aider.conf.yml", ".aider.conf.yaml",
    ".clinerules", ".roo", ".cursor/rules", ".claude/skills", ".claude/agents",
]

PACKAGE_MANAGER_FILES = {
    "package-lock.json": "npm", "npm-shrinkwrap.json": "npm",
    "pnpm-lock.yaml": "pnpm", "yarn.lock": "yarn", "bun.lockb": "bun",
    "bun.lock": "bun", "poetry.lock": "poetry", "uv.lock": "uv",
    "Pipfile.lock": "pipenv", "requirements.txt": "pip",
    "Cargo.lock": "cargo", "go.sum": "go", "Gemfile.lock": "bundler",
    "composer.lock": "composer", "gradle.lockfile": "gradle",
}

CI_PREFIXES = (
    ".github/workflows/", ".gitlab-ci.yml", "circle.yml", ".circleci/",
    "Jenkinsfile", "azure-pipelines.yml", "bitbucket-pipelines.yml",
    ".buildkite/", ".drone.yml",
)


def is_secretish(rel: str) -> bool:
    parts = Path(rel).parts
    for part in parts:
        if part == ".env" or part.startswith(".env."):
            return True
        if SECRET_NAME_RE.search(part):
            return True
    return False


def walk_files(root: Path, max_files: int) -> list[str]:
    files: list[str] = []
    for current, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = [d for d in dirs if d not in IGNORED_DIRS]
        current_path = Path(current)
        for name in names:
            path = current_path / name
            try:
                if path.is_symlink() or not path.is_file():
                    continue
            except OSError:
                continue
            rel = path.relative_to(root).as_posix()
            files.append(rel)
            if len(files) >= max_files:
                return files
    return files


def safe_json(path: Path, max_bytes: int = 1_000_000) -> dict[str, Any] | None:
    try:
        if path.stat().st_size > max_bytes:
            return None
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def package_json_scripts(root: Path) -> dict[str, str]:
    data = safe_json(root / "package.json")
    if not isinstance(data, dict):
        return {}
    scripts = data.get("scripts")
    if not isinstance(scripts, dict):
        return {}
    useful = {}
    for name, value in scripts.items():
        if isinstance(value, str) and name.lower() in {
            "build", "test", "lint", "format", "typecheck", "type-check",
            "check", "ci", "verify", "dev", "start"
        }:
            useful[name] = value
    return useful


def make_targets(root: Path) -> list[str]:
    path = root / "Makefile"
    if not path.exists() or path.stat().st_size > 1_000_000:
        return []
    targets: list[str] = []
    try:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith((" ", "\t", "#", ".")):
                continue
            m = re.match(r"^([A-Za-z0-9_.-]+)\s*:(?![=])", line)
            if m:
                target = m.group(1)
                if target not in targets:
                    targets.append(target)
            if len(targets) >= 40:
                break
    except OSError:
        return []
    return targets


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("repo", nargs="?", default=".")
    ap.add_argument("--max-files", type=int, default=20_000)
    args = ap.parse_args()

    root = Path(args.repo).expanduser().resolve()
    if not root.exists() or not root.is_dir():
        raise SystemExit(f"Repository directory not found: {root}")

    files = walk_files(root, max(1, args.max_files))
    file_set = set(files)

    languages = Counter()
    for rel in files:
        ext = Path(rel).suffix.lower()
        lang = LANG_EXTENSIONS.get(ext)
        if lang:
            languages[lang] += 1

    package_managers = sorted({
        manager for filename, manager in PACKAGE_MANAGER_FILES.items()
        if filename in file_set
    })

    assistant_surfaces: list[str] = []
    for surface in ASSISTANT_SURFACES:
        if surface in file_set or any(f.startswith(surface.rstrip("/") + "/") for f in files):
            assistant_surfaces.append(surface)

    ci_files = [
        f for f in files
        if any(f == p or f.startswith(p) for p in CI_PREFIXES)
    ][:100]

    manifests = [
        f for f in files if Path(f).name in {
            "package.json", "pyproject.toml", "Cargo.toml", "go.mod", "Gemfile",
            "composer.json", "pom.xml", "build.gradle", "build.gradle.kts",
            "Makefile", "Taskfile.yml", "justfile"
        }
    ][:100]

    result = {
        "root": str(root),
        "files_scanned": len(files),
        "scan_truncated": len(files) >= args.max_files,
        "languages_by_file_count": dict(languages.most_common()),
        "package_managers": package_managers,
        "manifests": manifests,
        "ci_files": ci_files,
        "assistant_config_surfaces": assistant_surfaces,
        "package_json_scripts": package_json_scripts(root),
        "make_targets": make_targets(root),
        "secretish_paths_detected_count": sum(1 for f in files if is_secretish(f)),
        "notes": [
            "Secret-like file contents were not read or printed.",
            "This is discovery evidence, not proof of command correctness; verify commands in the live project."
        ],
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
