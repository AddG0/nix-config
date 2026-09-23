#!/usr/bin/env python3
"""Validate a canonical code-assistant manifest.

Errors indicate structural/safety problems that should block acceptance.
Warnings indicate design risks that require review. This validator is
intentionally platform-neutral; native adapter validation still applies.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError as exc:  # pragma: no cover
    raise SystemExit("PyYAML is required to validate YAML manifests") from exc

HIGH_RISK_EFFECTS = {
    "external-write", "publish", "deploy", "delete", "credential-change",
    "production-mutation", "privileged",
}
WRITE_EFFECTS = {"filesystem-write", "process-execution"} | HIGH_RISK_EFFECTS


def load(path: Path) -> Any:
    text = path.read_text(encoding="utf-8")
    if path.suffix.lower() == ".json":
        return json.loads(text)
    return yaml.safe_load(text)


def listify(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def validate(data: Any) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    if not isinstance(data, dict):
        return ["Manifest root must be a mapping/object."], warnings

    for key in ("api_version", "kind", "metadata", "spec"):
        if key not in data:
            errors.append(f"Missing top-level field: {key}")

    if data.get("kind") not in (None, "CodeAssistant"):
        warnings.append("kind is not 'CodeAssistant'; confirm a compatible canonical schema.")

    metadata = data.get("metadata") if isinstance(data.get("metadata"), dict) else {}
    spec = data.get("spec") if isinstance(data.get("spec"), dict) else {}

    for key in ("name", "version"):
        if not metadata.get(key):
            warnings.append(f"metadata.{key} is recommended for reproducibility.")
    if not metadata.get("owner"):
        warnings.append("metadata.owner is recommended for governance.")

    if not spec.get("purpose"):
        errors.append("spec.purpose is required.")
    if "non_goals" not in spec:
        warnings.append("spec.non_goals is recommended to constrain scope creep.")

    architecture = spec.get("architecture") if isinstance(spec.get("architecture"), dict) else {}
    arch_type = architecture.get("type", "single-agent")
    agents = architecture.get("agents") if isinstance(architecture.get("agents"), dict) else {}
    if arch_type != "single-agent" and len(agents) < 2:
        warnings.append("Non-single-agent architecture declares fewer than two agents.")
    if len(agents) > 1:
        for name, cfg in agents.items():
            if isinstance(cfg, dict) and not cfg.get("role"):
                warnings.append(f"Agent '{name}' lacks an explicit role/purpose.")

    tools = listify(spec.get("tools"))
    effects_seen: set[str] = set()
    tool_ids: set[str] = set()
    for i, tool in enumerate(tools):
        if not isinstance(tool, dict):
            errors.append(f"spec.tools[{i}] must be a mapping.")
            continue
        tid = tool.get("id")
        if not tid:
            errors.append(f"spec.tools[{i}] missing id.")
        elif tid in tool_ids:
            errors.append(f"Duplicate tool id: {tid}")
        else:
            tool_ids.add(str(tid))
        effects = listify(tool.get("effects"))
        if not effects:
            errors.append(f"Tool '{tid or i}' must declare effects.")
        effects_seen.update(str(e) for e in effects)
        if not tool.get("risk"):
            errors.append(f"Tool '{tid or i}' must declare risk.")
        if any(str(e) in HIGH_RISK_EFFECTS for e in effects):
            auth = tool.get("authorization")
            if not auth:
                warnings.append(f"High-risk tool '{tid or i}' has no tool-level authorization metadata.")

    permissions = spec.get("permissions") if isinstance(spec.get("permissions"), dict) else {}
    if effects_seen & WRITE_EFFECTS:
        if not permissions:
            errors.append("Write/execution effects exist but spec.permissions is missing.")
        if "default" not in permissions:
            warnings.append("spec.permissions.default should be explicit when write/execution effects exist.")

    sandbox = spec.get("sandbox") if isinstance(spec.get("sandbox"), dict) else {}
    if "filesystem-write" in effects_seen and not sandbox:
        warnings.append("Filesystem writes exist without an explicit sandbox section.")
    if effects_seen & {"network-read", "external-write", "publish", "deploy", "production-mutation"}:
        network = sandbox.get("network") if isinstance(sandbox.get("network"), dict) else {}
        if not network:
            warnings.append("Network/external effects exist without explicit sandbox.network policy.")

    approvals = listify(spec.get("approvals"))
    permissions_ask = listify(permissions.get("ask"))
    if effects_seen & HIGH_RISK_EFFECTS and not approvals and not permissions_ask:
        errors.append("High-risk effects exist without approval or ask policy.")

    verification = spec.get("verification") if isinstance(spec.get("verification"), dict) else {}
    if effects_seen & WRITE_EFFECTS:
        if not verification:
            errors.append("Write/execution effects exist without spec.verification.")
        elif verification.get("required_before_success") is not True:
            warnings.append("Write/execution systems should normally require verification before success.")
        if not listify(verification.get("steps")):
            warnings.append("Verification is configured but has no steps.")

    budgets = spec.get("budgets") if isinstance(spec.get("budgets"), dict) else {}
    if not budgets:
        warnings.append("spec.budgets is recommended to bound autonomy.")
    for key in ("max_tool_calls", "max_fix_cycles", "wall_clock_minutes"):
        if key in budgets:
            val = budgets[key]
            if not isinstance(val, (int, float)) or val <= 0:
                errors.append(f"spec.budgets.{key} must be a positive finite number.")

    failure = spec.get("failure") if isinstance(spec.get("failure"), dict) else {}
    if effects_seen & HIGH_RISK_EFFECTS:
        if failure.get("authorization_error") not in ("fail-closed", "deny", "stop-and-escalate"):
            warnings.append("High-risk systems should fail closed on authorization errors.")

    obs = spec.get("observability") if isinstance(spec.get("observability"), dict) else {}
    if not obs:
        warnings.append("spec.observability is recommended for nontrivial agents.")
    if obs.get("sensitive_content") is True:
        warnings.append("Sensitive content logging is enabled; require explicit privacy/security review.")

    evals = spec.get("evals") if isinstance(spec.get("evals"), dict) else {}
    if not evals:
        warnings.append("spec.evals is recommended for regression protection.")
    else:
        for key in ("trigger", "trajectory", "outcome"):
            if key not in evals:
                warnings.append(f"spec.evals.{key} is not declared.")
        if effects_seen & HIGH_RISK_EFFECTS and not evals.get("adversarial"):
            warnings.append("High-risk effects exist without adversarial evals enabled.")

    return errors, warnings


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("manifest")
    ap.add_argument("--json", action="store_true", dest="as_json")
    args = ap.parse_args()

    path = Path(args.manifest)
    data = load(path)
    errors, warnings = validate(data)
    result = {"valid": not errors, "errors": errors, "warnings": warnings}

    if args.as_json:
        print(json.dumps(result, indent=2))
    else:
        print("VALID" if not errors else "INVALID")
        for item in errors:
            print(f"ERROR: {item}")
        for item in warnings:
            print(f"WARN: {item}")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
