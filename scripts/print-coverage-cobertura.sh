#!/bin/zsh

# Parses coverage file in cobertura format and prints out overall code coverage

TOTAL_XCTEST_COVERAGE=`grep '<coverage' $1 | perl -pe 's/.+?line-rate=\"(\d+\.\d+)\".+/\1/'`
COVERAGE_PERCENTAGE=`echo $(( 100 * $TOTAL_XCTEST_COVERAGE ))`
echo "Total test coverage: $COVERAGE_PERCENTAGE%"

