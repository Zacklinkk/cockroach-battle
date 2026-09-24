#!/usr/bin/env python3
"""Reassemble GitHub sized game files and verify their original hashes."""

import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs/github-chunk-manifest.json"


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def main():
    files = json.loads(MANIFEST.read_text())
    for entry in files:
        target = ROOT / entry["path"]
        if target.exists() and target.stat().st_size == entry["size"] and digest(target) == entry["sha256"]:
            print(f"OK {entry['path']}")
            continue
        temporary = target.with_name(target.name + ".restoring")
        try:
            with temporary.open("wb") as out:
                for part in entry["parts"]:
                    with (ROOT / part).open("rb") as source:
                        for block in iter(lambda: source.read(1024 * 1024), b""):
                            out.write(block)
            if temporary.stat().st_size != entry["size"] or digest(temporary) != entry["sha256"]:
                raise ValueError(f"Hash mismatch: {entry['path']}")
            temporary.replace(target)
            print(f"Restored {entry['path']}")
        finally:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        sys.exit(str(error))
