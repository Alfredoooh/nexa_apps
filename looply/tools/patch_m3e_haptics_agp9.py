#!/usr/bin/env python3
"""Patch m3e_haptics 1.x Android build script for AGP 9 built-in Kotlin.

The published plugin still applies the legacy Kotlin Android Gradle plugin and
omits compileSdk in its Android library module. AGP 9 provides Kotlin itself,
so the legacy plugin must be removed and the library's compile SDK declared.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path


def patch_gradle_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    updated = original

    # Remove the legacy Kotlin Gradle plugin from both plugins {} and apply
    # plugin declarations. The Android library plugin remains enabled.
    patterns = (
        re.compile(
            r"(?m)^\s*id\s*(?:\(\s*)?['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"]"
            r"\s*\)?(?:\s+version\s+['\"][^'\"]+['\"])?(?:\s+apply\s+(?:false|true))?\s*;?\s*$"
        ),
        re.compile(
            r"(?m)^\s*apply\s+plugin\s*:\s*['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"]\s*;?\s*$"
        ),
    )
    removed_legacy_plugin = False
    for pattern in patterns:
        updated, count = pattern.subn("", updated)
        removed_legacy_plugin = removed_legacy_plugin or count > 0

    # If a variant of the legacy plugin declaration is not recognized, fail
    # instead of silently allowing the original AGP 9 failure to recur.
    legacy_apply = re.compile(
        r"(?im)^\s*(?:id\s*\(?\s*['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"]|"
        r"apply\s+plugin\s*:\s*['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"])"
    )
    if legacy_apply.search(updated):
        raise RuntimeError(f"Could not remove legacy Kotlin plugin declaration in {path}")

    # AGP 9 requires every Android library module to declare compileSdk.
    android_block = re.search(r"(?m)^(\s*)android\s*\{", updated)
    if not android_block:
        raise RuntimeError(f"Android block not found in {path}")

    if not re.search(r"(?im)^\s*compileSdk(?:Version)?\s*(?:=|\s)", updated):
        insert_at = android_block.end()
        updated = updated[:insert_at] + "\n    compileSdk = 36" + updated[insert_at:]

    if updated != original:
        path.write_text(updated, encoding="utf-8")
        print(f"Patched AGP 9 compatibility: {path}")
    else:
        print(f"Already compatible: {path}")

    return updated != original


def main() -> int:
    # Respect the same cache location used by `flutter pub get` in CI.
    # PUB_CACHE is commonly set by GitHub Actions; otherwise use Dart's
    # platform default cache location.
    configured_cache = os.environ.get("PUB_CACHE")
    if configured_cache:
        pub_cache = Path(configured_cache).expanduser()
    elif os.name == "nt":
        local_app_data = os.environ.get("LOCALAPPDATA")
        pub_cache = (
            Path(local_app_data) / "Pub" / "Cache"
            if local_app_data
            else Path.home() / "AppData" / "Local" / "Pub" / "Cache"
        )
    else:
        pub_cache = Path.home() / ".pub-cache"

    candidates = sorted(
        pub_cache.glob("hosted/*/m3e_haptics-*/android/build.gradle")
    )

    if not candidates:
        print(
            "ERROR: m3e_haptics Android Gradle file was not found in "
            f"the Pub cache at {pub_cache}. Run 'flutter pub get' before "
            "the Gradle build and make sure PUB_CACHE points to that cache.",
            file=sys.stderr,
        )
        return 1

    try:
        for gradle_file in candidates:
            patch_gradle_file(gradle_file)
    except (OSError, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
