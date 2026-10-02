#!/usr/bin/env python3
"""Add new localized strings to every ARB file, safely.

Usage:
    python3 tool/arb_add.py strings.json

strings.json:
    {
      "someKey": {
        "description": "Where it shows and what it means (goes to app_en.arb).",
        "placeholders": {"name": {"type": "String"}},   # optional
        "en": "Hello {name}", "tr": "...", "ar": "...", "es": "...",
        "fr": "...", "hi": "...", "ja": "...", "ko": "...",
        "pt_BR": "...", "pt": "...", "sv": "...", "zh": "..."
      }
    }

Every locale is required: a missing translation is an error, not a silent
English fallback. Holds an exclusive lock for the whole edit and the
`flutter gen-l10n` run after it, so several people (or agents) adding strings
at once cannot overwrite each other's keys.

Appends text before each file's closing brace rather than re-serialising the
JSON, so nothing else in the file moves (app_en.arb has hand-indented entries a
re-dump would churn). New keys only: an existing key is an error — edit an
existing string by hand.
"""

import fcntl
import json
import subprocess
import sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "lib" / "l10n"
LOCALES = ["en", "tr", "ar", "es", "fr", "hi", "ja", "ko", "pt_BR", "pt", "sv", "zh"]
LOCK = ROOT / "build" / ".arb.lock"


def main() -> None:
    spec = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    for key, entry in spec.items():
        missing = [l for l in LOCALES if l not in entry]
        if missing:
            sys.exit(f"{key}: missing locales {missing}")
        if "description" not in entry:
            sys.exit(f"{key}: missing description")

    LOCK.parent.mkdir(parents=True, exist_ok=True)
    with open(LOCK, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for loc in LOCALES:
            path = L10N / f"app_{loc}.arb"
            text = path.read_text(encoding="utf-8")
            existing = json.loads(text)
            dupes = [k for k in spec if k in existing]
            if dupes:
                sys.exit(f"app_{loc}.arb already has {dupes}")
            lines = []
            for key, entry in spec.items():
                lines.append(f"  {json.dumps(key)}: "
                             f"{json.dumps(entry[loc], ensure_ascii=False)}")
                if loc == "en":
                    meta = OrderedDict(description=entry["description"])
                    if "placeholders" in entry:
                        meta["placeholders"] = entry["placeholders"]
                    body = json.dumps(meta, ensure_ascii=False, indent=2)
                    body = body.replace("\n", "\n  ")
                    lines.append(f"  {json.dumps('@' + key)}: {body}")
            head = text.rstrip()
            assert head.endswith("}"), path
            head = head[:-1].rstrip()
            path.write_text(head + ",\n" + ",\n".join(lines) + "\n}\n",
                            encoding="utf-8")
            json.loads(path.read_text(encoding="utf-8"))  # still valid
        subprocess.run(["flutter", "gen-l10n"], cwd=ROOT, check=True,
                       stdout=subprocess.DEVNULL)
        fcntl.flock(lock, fcntl.LOCK_UN)
    print(f"added {len(spec)} key(s) to {len(LOCALES)} locales")


if __name__ == "__main__":
    main()
