#!/bin/bash

CLASS_NAME="ObfuscatedConstants"
FILE_NAME="$CLASS_NAME.swift"
EXAMPLE_FILE_NAME="$CLASS_NAME.example.swift"

FILE_CONTENT="import Foundation

class $CLASS_NAME {
    
"

# $1: variable line
addVariableToFile () {
    VARIABLE_STRING="    $1"
    FILE_CONTENT="$FILE_CONTENT$VARIABLE_STRING
"
}

ENV_VARS_FOUND=0

# Parse example file and replace the default values based on env vars of the same names
while read line
do
    if [[ $line == "static let "* ]]; then
        LINE_REMAINDER=${line#"static let "}
        VARIABLE_NAME=$(echo $LINE_REMAINDER | awk '{print $1;}')
        VARIABLE_NAME="${VARIABLE_NAME//:}" # remove collon

        VARIABLE_VALUE=$(eval echo "\$$VARIABLE_NAME")
        if [[ ! -z "$VARIABLE_VALUE" ]]; then
            addVariableToFile "$VARIABLE_VALUE"
            ((ENV_VARS_FOUND++))
        else # copy line verbatum from example file
            FILE_CONTENT="$FILE_CONTENT$line
"
        fi
    fi
done <<< "$(cat $EXAMPLE_FILE_NAME)"

FILE_CONTENT="$FILE_CONTENT
}"

# If there is no file, copy the example file
if [[ ! -f $FILE_NAME ]]; then
    echo "Copying example file"
    cp $EXAMPLE_FILE_NAME $FILE_NAME
fi

# If there are any environment variables (and they have changed
# from the content of the generated file), overwrite the file
if [ "$(< $FILE_NAME)" != "$FILE_CONTENT" ] && [ "$ENV_VARS_FOUND" != 0 ]; then
    echo "Overwriting file"
    echo "$FILE_CONTENT" > $FILE_NAME
else
    echo "Not overwriting file"
fi
