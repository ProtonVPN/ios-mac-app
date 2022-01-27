#!/bin/bash

# Parses coverage file and prints out overall code coverage
LINE_NR="${3:-1}"

TOTAL_XCTEST_COVERAGE=`xcrun xccov view --report $1 | grep "$2" | head -$LINE_NR | tail -n 1 | perl -pe 's/.+?(\d+\.\d+%).+/\1/'`
echo "Total test coverage: $TOTAL_XCTEST_COVERAGE"

