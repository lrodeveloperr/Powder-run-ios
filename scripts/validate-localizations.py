#!/usr/bin/env python3
"""Reject selectable locales without complete matching string catalogs."""

from pathlib import Path
from collections import Counter
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "Shell/App/ShellConfiguration.swift"
RESOURCES = ROOT / "Shell/Resources"

configured = re.findall(r'\.init\(id: "([^"]+)", displayName:', CONFIG.read_text())
locales = [locale for locale in configured if locale != "system"]

def catalog(path: Path) -> dict[str, str]:
    found = re.findall(
        r'^\s*"((?:\\.|[^"])*)"\s*=\s*"((?:\\.|[^"])*)"\s*;',
        path.read_text(),
        re.MULTILINE,
    )
    found_keys = [key for key, _ in found]
    if len(found_keys) != len(set(found_keys)):
        sys.exit(f"LOCALIZATION FAILED: duplicate keys in {path.relative_to(ROOT)}")
    return dict(found)

def placeholders(value: str) -> Counter[str]:
    return Counter(re.findall(r'%(?:\d+\$)?(@|lld|ld|d|f|s)', value))

english_path = RESOURCES / "en.lproj/Localizable.strings"
if not english_path.is_file():
    sys.exit("LOCALIZATION FAILED: missing English source catalog")
english_catalog = catalog(english_path)
english = set(english_catalog)

for locale in locales:
    path = RESOURCES / f"{locale}.lproj/Localizable.strings"
    if not path.is_file():
        sys.exit(f"LOCALIZATION FAILED: selectable locale {locale} has no matching catalog")
    current_catalog = catalog(path)
    current = set(current_catalog)
    missing = sorted(english - current)
    extra = sorted(current - english)
    if missing or extra:
        sys.exit(f"LOCALIZATION FAILED: {locale} key mismatch; missing={missing[:8]} extra={extra[:8]}")
    mismatched_placeholders = sorted(
        key for key in english
        if placeholders(english_catalog[key]) != placeholders(current_catalog[key])
    )
    if mismatched_placeholders:
        sys.exit(
            f"LOCALIZATION FAILED: {locale} placeholder mismatch; "
            f"keys={mismatched_placeholders[:8]}"
        )

print(f"Localization validation passed ({len(locales)} selectable locale catalogs, {len(english)} keys).")
