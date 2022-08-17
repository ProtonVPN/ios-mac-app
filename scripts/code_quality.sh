#!/bin/bash

function process() {
    name=($(basename "$(dirname "$2")"))
    path="$1/$name"
    
    echo "---------- Linting $name ----------"
    
    cd $path
    swiftlint --strict --reporter codeclimate > codequality_report.json

    pattern="\"path\" : \""
    replacement="\"path\" : \"$1\/$name\/"
    sed -i'' -e "s/$pattern/$replacement/g" codequality_report.json
    cd -
}

for target in libraries/**/.swiftlint.yml
do
    process "libraries" $target
done

jq -s '[.[][]]' libraries/**/codequality_report.json > codequality_report.json

for target in apps/**/.swiftlint.yml
do
    process "apps" $target
done

jq -s '[.[][]]' apps/**/codequality_report.json > codequality_report.json
