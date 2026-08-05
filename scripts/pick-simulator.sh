#!/usr/bin/env bash
# Prints the UDID of an available iPhone simulator on this machine.
#
# `xcodebuild test` will not accept a generic destination the way `build` does — it needs a
# concrete simulator. Hard-coding a device name ("iPhone 16") is the usual approach and it
# breaks silently the week the runner image ships a different set, turning a green suite
# into an unexplained failure. Looking the UDID up means CI keeps working across image
# updates without anyone noticing they happened.
#
# Exits non-zero with a message on stderr if the machine has no iPhone simulator at all.

set -uo pipefail

udid=$(xcrun simctl list devices available --json | python3 -c '
import json, sys

data = json.load(sys.stdin)["devices"]
best_runtime = ""
best_udid = ""
best_name = ""

for runtime, devices in data.items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if not device.get("isAvailable"):
            continue
        if "iPhone" not in device["name"]:
            continue
        # Runtimes sort lexically close enough to version order for our purposes, and
        # within a runtime the last iPhone listed is the newest model.
        if runtime >= best_runtime:
            best_runtime = runtime
            best_udid = device["udid"]
            best_name = device["name"]

if best_udid:
    print(best_udid)
    print("%s on %s" % (best_name, best_runtime.split(".")[-1]), file=sys.stderr)
')

if [ -z "$udid" ]; then
  echo "No available iPhone simulator found on this machine." >&2
  exit 1
fi

echo "$udid"
