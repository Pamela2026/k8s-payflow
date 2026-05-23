#!/usr/bin/env python3
"""Render the pipeline contract policy and layer impact summaries."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any

try:
    import yaml
except ImportError as exc:  # pragma: no cover - workflow installs dependency
    raise SystemExit(
        "PyYAML is required. Install it with: python -m pip install pyyaml"
    ) from exc


def _fmt_list(values: list[str]) -> str:
    return ", ".join(values) if values else "-"


def load_policy(policy_path: Path) -> dict[str, Any]:
    data = yaml.safe_load(policy_path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"Policy file has an unexpected shape: {policy_path}")
    return data


def get_layers(policy: dict[str, Any]) -> dict[str, Any]:
    layers = policy.get("layers", {})
    if not isinstance(layers, dict):
        raise SystemExit("Policy file is missing a valid 'layers' mapping.")
    return layers


def get_layer(policy: dict[str, Any], layer_name: str) -> dict[str, Any]:
    layers = get_layers(policy)
    layer = layers.get(layer_name)
    if not isinstance(layer, dict):
        raise SystemExit(f"Unknown layer: {layer_name}")
    return layer


def contract_actions(layer: dict[str, Any]) -> dict[str, list[str]]:
    on_change = layer.get("on_contract_change", {})
    if not isinstance(on_change, dict):
        return {}

    actions: dict[str, list[str]] = {}
    for action_name in ("replan", "resync", "reverify"):
        targets = on_change.get(action_name, [])
        if isinstance(targets, list):
            actions[action_name] = [str(target) for target in targets]
        else:
            actions[action_name] = []
    return actions


def impacted_consumers(layer: dict[str, Any], changed_outputs: list[str]) -> dict[str, Any]:
    contract_outputs = [
        str(value) for value in layer.get("contract_outputs", []) if value is not None
    ]
    consumers = [str(value) for value in layer.get("consumers", []) if value is not None]
    matched = [output for output in changed_outputs if output in contract_outputs]
    actions = contract_actions(layer)
    impacted = sorted(
        {
            target
            for target_list in actions.values()
            for target in target_list
        }
    )
    needs_followup = bool(matched) and bool(impacted)

    return {
        "contract_outputs": contract_outputs,
        "consumers": consumers,
        "changed_outputs": changed_outputs,
        "matched_contract_outputs": matched,
        "actions": actions,
        "impacted_consumers": impacted,
        "needs_followup": needs_followup,
    }


def render_summary(policy_path: Path) -> str:
    policy = load_policy(policy_path)
    layers = get_layers(policy)
    policy_meta = policy.get("policy", {})
    if not isinstance(policy_meta, dict):
        policy_meta = {}

    lines: list[str] = []
    lines.append("## Pipeline Contract Policy")
    lines.append("")
    lines.append(f"- Mode: `{policy_meta.get('mode', 'unknown')}`")
    lines.append(
        f"- Prod manual approval: `{policy_meta.get('prod_requires_manual_approval', False)}`"
    )
    lines.append(
        f"- Rollback manual approval: `{policy_meta.get('rollback_requires_manual_approval', False)}`"
    )
    lines.append("")
    lines.append("| Layer | Contract Outputs | Consumers | Contract Change Actions |")
    lines.append("|---|---|---|---|")

    for layer_name, layer in layers.items():
        if not isinstance(layer, dict):
            continue
        outputs = _fmt_list([str(value) for value in layer.get("contract_outputs", [])])
        consumers = _fmt_list([str(value) for value in layer.get("consumers", [])])
        actions = []
        for action_name, targets in contract_actions(layer).items():
            if targets:
                actions.append(f"{action_name}: {_fmt_list(targets)}")
        if not actions:
            actions.append("-")
        lines.append(
            f"| `{layer_name}` | {outputs} | {consumers} | {'<br>'.join(actions)} |"
        )

    return "\n".join(lines) + "\n"


def render_layer_report(layer_name: str, impact: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append(f"## Layer Impact: `{layer_name}`")
    lines.append("")
    lines.append(f"- Changed outputs: `{_fmt_list(impact['changed_outputs'])}`")
    lines.append(
        f"- Matched contract outputs: `{_fmt_list(impact['matched_contract_outputs'])}`"
    )
    lines.append(f"- Consumers: `{_fmt_list(impact['consumers'])}`")
    lines.append(
        f"- Impacted consumers: `{_fmt_list(impact['impacted_consumers'])}`"
    )
    lines.append(
        f"- Downstream follow-up needed: `{str(impact['needs_followup']).lower()}`"
    )
    lines.append("")
    lines.append("| Action | Targets |")
    lines.append("|---|---|")
    for action_name in ("replan", "resync", "reverify"):
        targets = impact["actions"].get(action_name, [])
        lines.append(f"| `{action_name}` | `{_fmt_list(targets)}` |")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--policy",
        default="pipeline-contracts.yml",
        help="Path to the policy YAML file.",
    )
    parser.add_argument(
        "--layer",
        help="Render a layer impact summary instead of the full policy summary.",
    )
    parser.add_argument(
        "--changed-output",
        action="append",
        default=[],
        dest="changed_outputs",
        help="A changed output name to evaluate. May be passed multiple times.",
    )
    parser.add_argument(
        "--format",
        choices=("markdown", "json"),
        default="markdown",
        help="Render markdown or JSON output.",
    )
    args = parser.parse_args()

    policy_path = Path(args.policy)
    if not policy_path.exists():
        print(f"Policy file not found: {policy_path}", file=sys.stderr)
        return 1

    policy = load_policy(policy_path)

    if args.layer:
        layer = get_layer(policy, args.layer)
        impact = impacted_consumers(layer, [str(value) for value in args.changed_outputs])
        if args.format == "json":
            payload = {
                "layer": args.layer,
                **impact,
            }
            sys.stdout.write(json.dumps(payload, indent=2, sort_keys=True) + "\n")
        else:
            sys.stdout.write(render_layer_report(args.layer, impact))
        return 0

    if args.format == "json":
        sys.stdout.write(json.dumps(policy, indent=2, sort_keys=True) + "\n")
    else:
        sys.stdout.write(render_summary(policy_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
