#!/usr/bin/env python3
"""Generate skills-catalog.json from skills/ directory.

Usage: python3 scripts/generate_catalog.py
Output: dist/skills-catalog.json
"""

import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"
OUTPUT_DIR = ROOT / "dist"
OUTPUT_FILE = OUTPUT_DIR / "skills-catalog.json"

SKILL_MD = "SKILL.md"
FRONTMATTER_RE = re.compile(r"\A---\s*\n(?P<meta>\{.*?\})\s*\n---", re.DOTALL)
H1_RE = re.compile(r"^#\s+(.+)$", re.MULTILINE)


def parse_skill_md(path: Path) -> tuple[dict, str]:
    """Parse SKILL.md, return (frontmatter_meta, h1_title)."""
    text = path.read_text(encoding="utf-8")
    m = FRONTMATTER_RE.match(text)
    if not m:
        raise ValueError(f"{path}: missing JSON frontmatter")
    meta = json.loads(m.group("meta"))
    h1m = H1_RE.search(text)
    title = h1m.group(1).strip() if h1m else meta.get("name", path.parent.name)
    return meta, title


def sha256_dir(directory: Path) -> str:
    """Compute combined SHA256 of all files in a directory (sorted by path)."""
    h = hashlib.sha256()
    for f in sorted(directory.rglob("*")):
        if f.is_file():
            h.update(f.read_bytes())
    return h.hexdigest()


def list_files(directory: Path) -> list[str]:
    """Return relative file paths in a directory."""
    return sorted(
        str(f.relative_to(directory))
        for f in directory.rglob("*")
        if f.is_file()
    )


def total_size(directory: Path) -> int:
    """Return total size in bytes of all files in a directory."""
    return sum(
        f.stat().st_size
        for f in directory.rglob("*")
        if f.is_file()
    )


GITHUB_RAW_BASE = "https://raw.githubusercontent.com/HammerMiner/hammer-claw-skills-lab/main"
PREVIEW_FILENAME = "preview.png"


def preview_url(skill_dir_name: str):
    """Return preview URL if preview.png exists in the skill directory."""
    png = SKILLS_DIR / skill_dir_name / PREVIEW_FILENAME
    return f"{GITHUB_RAW_BASE}/skills/{skill_dir_name}/{PREVIEW_FILENAME}" if png.is_file() else None


def main():
    if not SKILLS_DIR.is_dir():
        print(f"ERROR: skills/ directory not found at {SKILLS_DIR}", file=sys.stderr)
        sys.exit(1)

    skills = []
    for skill_dir in sorted(SKILLS_DIR.iterdir()):
        if not skill_dir.is_dir():
            continue

        skill_md = skill_dir / SKILL_MD
        if not skill_md.is_file():
            print(f"WARNING: {skill_dir.name}: no SKILL.md, skipping", file=sys.stderr)
            continue

        try:
            meta, title = parse_skill_md(skill_md)
        except (ValueError, json.JSONDecodeError) as e:
            print(f"WARNING: {skill_dir.name}: {e}, skipping", file=sys.stderr)
            continue

        skill_id = meta.get("name", skill_dir.name)
        metadata = meta.get("metadata", {})

        categories = metadata.get("category", ["utility"])
        if not isinstance(categories, list) or not categories:
            categories = ["utility"]

        preview = preview_url(skill_dir.name)

        entry = {
            "id": skill_id,
            "title": title,
            "description": meta.get("description", ""),
            "author": meta.get("author", ""),
            "category": categories[0],  # primary category (backward compat)
            "categories": categories,    # all categories (new)
            "preview_url": preview,      # raw GitHub URL for preview thumbnail
            "devices": metadata.get("devices", ["universal"]),
            "peripherals": metadata.get("peripherals", []),
            "cap_groups": metadata.get("cap_groups", []),
            "total_size": total_size(skill_dir),
            "sha256": sha256_dir(skill_dir),
            "files": list_files(skill_dir),
        }
        skills.append(entry)

    catalog = {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "repo": "HammerMiner/hammer-claw-skills-lab",
        "total": len(skills),
        "skills": skills,
    }

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(
        json.dumps(catalog, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Generated {OUTPUT_FILE}: {len(skills)} skills")


if __name__ == "__main__":
    main()
