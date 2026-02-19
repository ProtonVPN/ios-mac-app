#!/bin/bash -e

# The build log may or may not contain log lines that indicate snapshot test
# failures. In case they do, they'll emit a log line that looks like this:
#
# SnapshotFailed: {"Original": "<path>", "Actual": "<path>", "Destination": "<path>"}
#
# This jq one-liner will find all of those log lines, parse the json, and
# generate 'mkdir' and 'cp' commands to make sure everything gets put in the
# right place.
#
# This has to be done here and not from the test bundle since the snapshot
# tests are run from the simulator context.

echo "Searching through $1 for failed snapshot tests..."

jq -Rr '
  select(test("^\\s*SnapshotFailed: {"))
  | sub("^\\s*SnapshotFailed:"; "")
  | fromjson
  | "mkdir -p $(dirname \(.Destination|@sh))\n" +
    "cp \(.Actual|@sh) \(.Destination|@sh)\n" +
    "echo Recorded snapshot \(.Destination|@sh)\n"
' < "$1" | sh
