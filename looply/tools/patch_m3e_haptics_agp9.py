#!/usr/bin/env python3
"""Migrate m3e_haptics Android Gradle script to AGP 9 built-in Kotlin.

The published m3e_haptics Android module applies the legacy
org.jetbrains.kotlin.android plugin, uses the removed android.kotlinOptions DSL,
and does not declare compileSdk. This patch removes the old plugin, migrates its
JVM target to kotlin.compilerOptions, and declares compileSdk for AGP 9.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path


def _matching_brace(source: str, opening_brace: int) -> int:
    """Return the matching closing brace, ignoring braces inside comments/strings."""
    depth = 0
    quote: str | None = None
    escaped = False
    line_comment = False
    block_comment = False
    i = opening_brace

    while i < len(source):
        char = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""

        if line_comment:
            if char == "\n":
                line_comment = False
            i += 1
            continue

        if block_comment:
            if char == "*" and nxt == "/":
                block_comment = False
                i += 2
            else:
                i += 1
            continue

        if quote is not None:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            i += 1
            continue

        if char == "/" and nxt == "/":
            line_comment = True
            i += 2
            continue
        if char == "/" and nxt == "*":
            block_comment = True
            i += 2
            continue
        if char in ("'", '"'):
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1

    raise RuntimeError("Unclosed Gradle block while migrating kotlinOptions")


def _extract_kotlin_options(source: str) -> tuple[str, list[str]]:
    """Remove legacy kotlinOptions blocks and return their JVM targets."""
    pattern = re.compile(r"\bkotlinOptions\s*\{")
    matches: list[tuple[int, int, str]] = []
    targets: list[str] = []

    for match in pattern.finditer(source):
        opening = source.find("{", match.start(), match.end())
        closing = _matching_brace(source, opening)
        body = source[opening + 1 : closing]

        target_matches = re.findall(
            r"(?im)^\s*jvmTarget\s*=\s*(['\"])([^'\"]+)\1\s*;?\s*$",
            body,
        )
        target_matches += re.findall(
            r"(?im)^\s*jvmTarget\s*\.set\(\s*(['\"])([^'\"]+)\1\s*\)\s*;?\s*$",
            body,
        )
        found_targets = [value for _, value in target_matches]
        targets.extend(found_targets)

        remainder = re.sub(
            r"(?im)^\s*jvmTarget\s*(?:=\s*(['\"])[^'\"]+\1|\.set\(\s*(['\"])[^'\"]+\2\s*\))\s*;?\s*$",
            "",
            body,
        )
        # Do not silently discard other compiler flags or settings.
        remainder = re.sub(r"(?m)^\s*//.*$", "", remainder)
        remainder = re.sub(r"(?s)/\*.*?\*/", "", remainder)
        if remainder.strip():
            raise RuntimeError(
                "m3e_haptics contains additional kotlinOptions settings that "
                "need explicit migration; refusing to discard them:\n"
                + remainder.strip()
            )
        matches.append((match.start(), closing + 1, body))

    # Remove from right to left so the stored source positions remain valid.
    for start, end, _ in reversed(matches):
        source = source[:start] + source[end:]

    unique_targets = list(dict.fromkeys(targets))
    if len(unique_targets) > 1:
        raise RuntimeError(
            "m3e_haptics declares conflicting kotlinOptions JVM targets: "
            + ", ".join(unique_targets)
        )
    return source, unique_targets


def _add_compiler_target(source: str, target: str) -> str:
    """Add the migrated JVM target to the built-in Kotlin compilerOptions DSL."""
    statement = (
        "jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget("
        f'"{target}"'
        ")"
    )

    kotlin_match = re.search(r"(?m)^\s*kotlin\s*\{", source)
    if not kotlin_match:
        return source.rstrip() + "\n\nkotlin {\n    compilerOptions {\n        " + statement + "\n    }\n}\n"

    kotlin_open = source.find("{", kotlin_match.start(), kotlin_match.end())
    kotlin_close = _matching_brace(source, kotlin_open)
    kotlin_body = source[kotlin_open + 1 : kotlin_close]

    existing_target = re.search(r"(?m)^\s*jvmTarget\s*=", kotlin_body)
    if existing_target:
        return source

    compiler_match = re.search(r"(?m)^\s*compilerOptions\s*\{", kotlin_body)
    if compiler_match:
        compiler_open = source.find("{", kotlin_open + 1 + compiler_match.start(), kotlin_open + 1 + compiler_match.end())
        compiler_close = _matching_brace(source, compiler_open)
        indent_match = re.search(r"(?m)^(\s*)compilerOptions\s*\{", source[kotlin_open + 1 + compiler_match.start():])
        indent = indent_match.group(1) + "    " if indent_match else "        "
        return source[:compiler_close] + "\n" + indent + statement + source[compiler_close:]

    return source[:kotlin_close] + "\n    compilerOptions {\n        " + statement + "\n    }\n" + source[kotlin_close:]


def patch_gradle_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    updated = original

    # Remove the legacy Kotlin Gradle plugin from plugins {} or apply plugin.
    patterns = (
        re.compile(
            r"(?m)^\s*id\s*(?:\(\s*)?['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"]"
            r"\s*\)?(?:\s+version\s+['\"][^'\"]+['\"])?(?:\s+apply\s+(?:false|true))?\s*;?\s*$"
        ),
        re.compile(
            r"(?m)^\s*apply\s+plugin\s*:\s*['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"]\s*;?\s*$"
        ),
    )
    for pattern in patterns:
        updated = pattern.sub("", updated)

    legacy_apply = re.compile(
        r"(?im)^\s*(?:id\s*\(?\s*['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"]|"
        r"apply\s+plugin\s*:\s*['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"])"
    )
    if legacy_apply.search(updated):
        raise RuntimeError(f"Could not remove legacy Kotlin plugin declaration in {path}")

    # Migrate android.kotlinOptions{} before adding compileSdk.
    updated, jvm_targets = _extract_kotlin_options(updated)
    if jvm_targets:
        updated = _add_compiler_target(updated, jvm_targets[0])

    android_block = re.search(r"(?m)^\s*android\s*\{", updated)
    if not android_block:
        raise RuntimeError(f"Android block not found in {path}")

    if not re.search(r"(?im)^\s*compileSdk(?:Version)?\s*(?:=|\s)", updated):
        insert_at = updated.find("{", android_block.start(), android_block.end()) + 1
        updated = updated[:insert_at] + "\n    compileSdk = 36" + updated[insert_at:]

    if updated != original:
        path.write_text(updated, encoding="utf-8")
        print(f"Patched AGP 9 compatibility: {path}")
    else:
        print(f"Already compatible: {path}")
    return updated != original


def main() -> int:
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

    candidates = sorted(pub_cache.glob("hosted/*/m3e_haptics-*/android/build.gradle"))
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
