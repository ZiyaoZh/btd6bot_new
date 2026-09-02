#!/usr/bin/env python3
"""Audit local BTD6 content consumers against BTD6ApiExplorer Constants.json."""

from __future__ import annotations

import argparse
import ast
import json
from pathlib import Path
from typing import Any


INSTA_CODES = (
    "000", "001", "002", "003", "004", "005", "010", "020",
    "030", "040", "050", "100", "200", "300", "400", "500",
)
SECTION_NAMES = {
    "英雄": "hero",
    "猴塔": "tower",
    "地图": "map",
    "BOSS气球": "boss",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--plugin-root", type=Path, default=Path("plugins/btd6bot_plugin"))
    return parser.parse_args()


def load_assignment(path: Path, name: str) -> Any:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    for node in tree.body:
        if isinstance(node, (ast.Assign, ast.AnnAssign)):
            target = node.targets[0] if isinstance(node, ast.Assign) else node.target
            if isinstance(target, ast.Name) and target.id == name:
                return ast.literal_eval(node.value)
    raise ValueError(f"{name} not found in {path}")


def ordered_keys(value: Any) -> list[str]:
    if isinstance(value, dict):
        return list(value)
    if isinstance(value, list):
        return [str(item) for item in value]
    raise TypeError(f"expected object or array, got {type(value).__name__}")


def parse_translation_keys(path: Path) -> dict[str, set[str]]:
    result = {name: set() for name in SECTION_NAMES.values()}
    section: str | None = None
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("## "):
            title = line[3:].split(".", 1)[-1].strip()
            section = SECTION_NAMES.get(title)
            continue
        if section is None or not (line.startswith("|") and line.endswith("|")):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        is_separator = bool(cells[0]) and set(cells[0]) <= {"-", ":"}
        if len(cells) >= 2 and cells[0] not in {"英文", "English"} and not is_separator:
            result[section].add(cells[0])
    return result


def main() -> int:
    args = parse_args()
    reference = args.reference.resolve()
    plugin = args.plugin_root.resolve()
    constants = json.loads(
        (reference / "data" / "Constants.json").read_text(encoding="utf-8")
    )

    towers = constants["towersInOrder"]
    tower_ids = list(towers)
    heroes = ordered_keys(constants["heroesInOrder"])
    maps = ordered_keys(constants["mapsInOrder"])
    bosses = ordered_keys(constants["bossesInOrder"])
    collection_order = list(constants["collection"]["towerOrder"])

    processor = plugin / "btd6_api_processor"
    local_categories = load_assignment(
        processor / "btd6_core" / "activity_repository.py", "TOWER_CATEGORIES"
    )
    local_collection = load_assignment(
        processor / "btd6_core" / "collection_event_service.py", "TOWER_POOL"
    )
    local_boxes = load_assignment(
        plugin / "ChatMonkeyTD" / "btd6_sim" / "config.py", "TOWER_POOL"
    )
    translations = parse_translation_keys(processor / "translate.md")

    issues: list[str] = []
    expected_categories = {
        key: value["category"].lower() for key, value in towers.items()
    }
    for tower_id, category in expected_categories.items():
        if local_categories.get(tower_id) != category:
            issues.append(
                f"activity category: {tower_id} expected {category!r}, "
                f"got {local_categories.get(tower_id)!r}"
            )

    if local_collection != collection_order:
        issues.append(
            "collection TOWER_POOL differs from ordered Constants.collection.towerOrder"
        )

    expected_box_pool = {
        "Wizard" if item == "WizardMonkey" else item for item in tower_ids
    }
    if set(local_boxes) != expected_box_pool:
        missing = sorted(expected_box_pool - set(local_boxes))
        extra = sorted(set(local_boxes) - expected_box_pool)
        issues.append(
            f"ChatMonkeyTD TOWER_POOL mismatch; missing={missing}, extra={extra}"
        )

    for section, expected in (
        ("tower", tower_ids),
        ("hero", heroes),
        ("map", maps),
        ("boss", bosses),
    ):
        missing = sorted(set(expected) - translations[section])
        if missing:
            issues.append(f"translate.md missing {section} IDs: {', '.join(missing)}")

    asset_roots = (
        processor / "assets" / "InstaMonkeyIcon",
        plugin / "ChatMonkeyTD" / "assets" / "InstaMonkeyIcon",
    )
    for asset_root in asset_roots:
        for tower_id in tower_ids:
            asset_id = "Wizard" if tower_id == "WizardMonkey" else tower_id
            for code in INSTA_CODES:
                asset = asset_root / f"{code}-{asset_id}Insta.webp"
                if not asset.is_file():
                    issues.append(f"missing asset: {asset}")

    print(
        f"reference version={constants.get('version')} "
        f"content={constants.get('projectContentVersion')} "
        f"towers={len(tower_ids)} heroes={len(heroes)} "
        f"maps={len(maps)} bosses={len(bosses)}"
    )
    if issues:
        print(f"FAIL: {len(issues)} issue(s)")
        for issue in issues:
            print(f"- {issue}")
        return 1
    print("OK: local content consumers match the reference catalog")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
