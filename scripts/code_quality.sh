#!/bin/bash

function process() {
    name=$(basename $2)
    path=$2
    
    echo "---------- Linting $name ----------"
    
    cd $path
    mint run -s swiftlint --strict --reporter codeclimate --config ../../.swiftlint.yml > codequality_report.json

    pattern="\"path\" : \""
    replacement="\"path\" : \"$1\/$name\/"
    sed -i'' -e "s/$pattern/$replacement/g" codequality_report.json
    cd -
}

for target in libraries/*/
do
    process "libraries" $target
done

jq -s '[.[][]]' libraries/**/codequality_report.json > codequality_report.json

for target in apps/*/
do
    process "apps" $target
done

jq -s '[.[][]]' apps/**/codequality_report.json > codequality_report.json
