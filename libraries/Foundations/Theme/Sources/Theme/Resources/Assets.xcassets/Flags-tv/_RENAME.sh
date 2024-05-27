#!/bin/bash

# # Find all files in the current directory and its subdirectories
# find . -type f | while read -r file; do
#     # Extract the base name of the file (without path)
#     base=$(basename "$file")
    
#     # Check if the length of the base name is 4 or less
#     if [ ${#base} -le 12 ]; then
#         echo $base
#         # Convert the base name to uppercase
#         newbase=$(echo "$base" | tr '[:lower:]' '[:upper:]')
        
#         # Extract the directory part of the file path
#         dir=$(dirname "$file")
        
#         # Construct the new file path
#         newfile="$dir/$newbase"
        
#         # Rename the file
#         mv "$file" "$newfile"
#     fi
# done

# # Find all files in the current directory and its subdirectories
# find . -type f | while read -r file; do
#     # Extract the base name of the file (without path)
#     base=$(basename "$file")
    
#     # Check if the length of the base name (without considering the extension) is 4 or less
#     base_name="${base%%.*}"
#     if [ ${#base_name} -le 12 ]; then
#         # Split the base name at the first dot
#         base_part="${base%%.*}"
#         ext_part="${base#*.}"

#         # Convert the base part to uppercase
#         new_base_part=$(echo "$base_part" | tr '[:lower:]' '[:upper:]')
#         new_ext_part=$(echo "$ext_part" | tr '[:upper:]' '[:lower:]')

#         # Reconstruct the new base name with the extension
#         if [ "$base_part" = "$base" ]; then
#             new_base="$new_base_part"
#         else
#             new_base="$new_base_part.$new_ext_part"
#         fi

#         # Extract the directory part of the file path
#         dir=$(dirname "$file")

#         # Construct the new file path
#         newfile="$dir/$new_base"

#         # Rename the file
#         mv "$file" "$newfile"
#     fi
# done

# Find all files in the current directory and its subdirectories, excluding "Contents.json"
find . -type f ! -name "Contents.json" | while read -r file; do
    # Extract the base name of the file (without path)
    base=$(basename "$file")
    
    # Extract the base name without extension
    base_name="${base%%.*}"
    
    # Check if the length of the base name (without extension) is 4 or less
    if [ ${#base_name} -le 4 ]; then
        # Split the base name at the first dot
        base_part="${base%%.*}"
        ext_part="${base#*.}"

        # Convert the base part to uppercase
        new_base_part=$(echo "$base_part" | tr '[:lower:]' '[:upper:]')
        new_ext_part=$(echo "$ext_part" | tr '[:upper:]' '[:lower:]')

        # Reconstruct the new base name with the extension
        if [ "$base_part" = "$base" ]; then
            new_base="$new_base_part"
        else
            new_base="$new_base_part.$new_ext_part"
        fi

        # Extract the directory part of the file path
        dir=$(dirname "$file")

        # Construct the new file path
        newfile="$dir/$new_base"

        # Rename the file
        mv "$file" "$newfile"
    fi
done





# # Find all Contents.json files in the current directory and its subdirectories
# find . -type f -name "Contents.json" | while read -r jsonfile; do
#     # Use jq to find and process each filename in the JSON file
#     jq '.images[] | select(has("filename")) | .filename' "$jsonfile" | while read -r filename; do
#         # Remove quotes around the filename
#         filename=$(echo "$filename" | tr -d '"')
        
#         # Split the filename at the first dot character
#         base="${filename%%.*}"
#         ext="${filename#*.}"
        
#         # Convert the base part to uppercase
#         newbase=$(echo "$base" | tr '[:lower:]' '[:upper:]')
        
#         # Reconstruct the filename
#         newfilename="$newbase.$ext"
        
#         # Replace the old filename with the new one in the JSON file
#         # Use jq to safely update the filename field
#         jq --arg old "$filename" --arg new "$newfilename" \
#            '(.images[] | select(.filename == $old) | .filename) = $new' "$jsonfile" > tmpfile && mv tmpfile "$jsonfile"
#     done
# done

# # Find all directories in the current directory and its subdirectories
# find . -type d | while read -r dir; do
#     # Extract the base name of the directory (without path)
#     base=$(basename "$dir")
    
#     # Skip the current directory (.)
#     if [ "$base" = "." ]; then
#         continue
#     fi

#     # Split the directory name at the first dot character
#     base_part="${base%%.*}"
#     ext_part="${base#*.}"

#     # Check if there is a dot in the directory name
#     if [ "$base" = "$base_part" ]; then
#         # No dot in the directory name, convert the whole name to uppercase
#         newbase=$(echo "$base" | tr '[:lower:]' '[:upper:]')
#     else
#         # Convert the base part to uppercase
#         newbase=$(echo "$base_part" | tr '[:lower:]' '[:upper:]')
        
#         # Reconstruct the directory name
#         newbase="$newbase.$ext_part"
#     fi
    
#     # Extract the parent directory part of the path
#     parent_dir=$(dirname "$dir")
    
#     # Construct the new directory path
#     newdir="$parent_dir/$newbase"
    
#     echo "$dir -> $newdir"

#     # Rename the directory
#     if [ "$dir" != "$newdir" ]; then
#         mv "$dir" "$newdir"
#     fi
# done