#!/bin/bash

# This script generates full Xcode projects for all the SPM packages as they are needed for strings export
# String export is done in the CI using `xcodebuild -exportLocalizations -localizationPath $outputDir -exportLanguage en`

# make sure dependencies are installed
xcodegen --version || brew install xcodegen

for package in libraries/**/Package.swift
do
    echo $package
    name=($(basename "$(dirname "$package")"))
    path="libraries/$name"

    # create a project definition file with just the strings
    cat << EOF > "$path/project.yml"
name: $name
targets:
  $name:
    type: framework
    platform: iOS
    deploymentTarget: "12.0"
    sources: [Sources/$name/Resources]
EOF
    # generate a classic Xcode project from the definition file
    # not doing it via `swift package generate-xcodeproj` because it is deprecated and ignores resource files mostly
    cd $path
    xcodegen generate
    cd -    
done