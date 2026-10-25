#!/usr/bin/env python3
"""Prints the UDID of the newest available iPhone simulator (used by CI)."""
import json
import subprocess
import sys


def main():
    raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
    devices = json.loads(raw)["devices"]
    best = None
    for runtime, devs in devices.items():
        if "iOS" not in runtime:
            continue
        version = tuple(int(x) for x in runtime.split("iOS-")[-1].split("-") if x.isdigit())
        for dev in devs:
            if not dev.get("isAvailable") or "iPhone" not in dev["name"]:
                continue
            key = (version, "Pro" in dev["name"], dev["name"])
            if best is None or key > best[0]:
                best = (key, dev["udid"], dev["name"], runtime)
    if best is None:
        print("no iPhone simulator available", file=sys.stderr)
        sys.exit(1)
    print(best[2], best[3], file=sys.stderr)
    print(best[1])


if __name__ == "__main__":
    main()
