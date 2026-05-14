#!/usr/bin/env python3
"""Normalize compile_commands.json for comparison.

Usage: normalize_ccdb.py <compile_commands.json> <repo_root>

Replaces repo_root with REPO_ROOT in all string values,
sorts entries by 'file', and prints normalized JSON.
"""
import json
import sys

data = json.load(open(sys.argv[1]))
root = sys.argv[2].rstrip("/")

for entry in data:
    for key in ("command", "file", "directory"):
        if key in entry:
            entry[key] = entry[key].replace(root, "REPO_ROOT")

print(json.dumps(sorted(data, key=lambda x: x["file"]), indent=2, sort_keys=True))
