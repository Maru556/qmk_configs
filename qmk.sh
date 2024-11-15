#!/bin/bash

# Function to find a file in Downloads
find_file() {
    local search_term="$1"
    local dl_path="$HOME/Downloads"
    for file_name in "$dl_path"/*; do
        if [[ "$file_name" == *"$search_term"* ]]; then
            echo "$file_name"
            return
        fi
    done
    echo ""
}

# Function to find the keyboard folder based on the full dynamic path
find_folder_in_script_directory() {
    local name="$1"
    local folder_name="${name}_kaito"
    local keyboard_base_path="$HOME/qmk_configs/keyboards"

    # Search for the keyboard folder in the full path structure
    local found_dir
    found_dir=$(find "$keyboard_base_path" -type d -name "$folder_name" 2>/dev/null | head -n 1)

    if [[ -n "$found_dir" ]]; then
        echo "$found_dir"  # Only return the found directory without extra messages
    else
        echo ""  # Return empty to signal failure
    fi
}

# Function to extract the keyboard name from the folder path
extract_keyboard_name() {
    local folder_path="$1"
    # Use awk to extract the part of the path between /keyboards/ and /keymaps/
    local keyboard_name=$(echo "$folder_path" | awk -F'/keyboards/|/keymaps/' '{print $2}')
    echo "$keyboard_name"
}

# Function to get the next version number
get_next_version_number() {
    local base_path="$HOME/qmk_configs"
    local base_name="$1"
    local version=0

    # Find all .uf2 files in the base path and determine the highest version number
    for file in "$base_path/${base_name}_"*.uf2; do
        if [[ -f "$file" ]]; then
            # Extract the version number
            if [[ "$file" =~ _([0-9]+)\.uf2$ ]]; then
                local file_version="${BASH_REMATCH[1]}"
                if (( file_version > version )); then
                    version=$file_version
                fi
            fi
        fi
    done

    # Increment version for the next file
    echo $((version + 1))
}

# Function to add lines to keymap.c
add_lines_to_keymap() {
    local keymap_file="$1"

    # Add lines you want to insert here
    cat <<EOL >> "$keymap_file"
#include QMK_KEYBOARD_H

void keyboard_pre_init_user(void) {
    setPinOutput(24);
    writePinHigh(24);
}
EOL
    echo "Added custom lines to $keymap_file"
}

# Main script
read -p "Enter name: " name
read -p "Enter converter: " convert_to

# Get the folder path
folder_path=$(find_folder_in_script_directory "$name")

if [[ -z "$folder_path" ]]; then
    echo "Failed to find the folder named '${name}_kaito'"
    exit 1
fi

# Verify the folder path
if [[ ! -d "$folder_path" ]]; then
    echo "Target folder '$folder_path' does not exist."
    exit 1
fi

keyboard_name=$(extract_keyboard_name "$folder_path")
if [[ -z "$keyboard_name" ]]; then
    echo "Failed to extract keyboard name."
    exit 1
fi

source_file=$(find_file "convert")
if [[ -z "$source_file" ]]; then
    echo "File containing 'convert' not found in Downloads."
    exit 1
fi

target_file="${folder_path}/$(basename "$source_file")"

# Copy the source file to the target location
cp "$source_file" "$target_file"
echo "Copied $source_file to $target_file"

# Remove existing keymap.c if it exists
keymap_path="${folder_path}/keymap.c"
if [[ -f "$keymap_path" ]]; then
    rm "$keymap_path"
    echo "Removed existing $keymap_path"
fi

# Run json2c using QMK CLI
json2c_output=$(qmk json2c -o "$folder_path"/keymap.c "$target_file" 2>&1)
if [[ $? -ne 0 ]]; then
    echo "json2c command failed with error:"
    echo "$json2c_output"
    exit 1
fi

# Check if keymap.c was created
if [[ ! -f "$keymap_path" ]]; then
    echo "Expected output file keymap.c not found after json2c command."
    echo "Check if the input file is valid: $target_file"
    exit 1
fi

# Add custom lines to keymap.c
add_lines_to_keymap "$keymap_path"

# Compile the firmware
compile_command="qmk compile -e CONVERT_TO=$convert_to -kb $keyboard_name -km ${name}_kaito"
echo "Running compile command: $compile_command"
compile_output=$($compile_command 2>&1)

# Output compile progress
if [[ $? -ne 0 ]]; then
    echo "Compile command failed with error:"
    echo "$compile_output"
    exit 1
fi

# Get the next version number
next_version=$(get_next_version_number "$name")

# Find the .uf2 file at the base of qmk_configs
uf2_file=$(find "$HOME/qmk_configs" -maxdepth 1 -name "*_${name}_*.uf2" | head -n 1)

if [[ -z "$uf2_file" ]]; then
    echo "No .uf2 file found after compilation."
    exit 1
fi

# Rename the .uf2 file
new_name="${HOME}/qmk_configs/${name}_kaito_${next_version}.uf2"
mv "$uf2_file" "$new_name"
echo "Renamed $uf2_file to $new_name"

# Remove the original file
rm "$source_file"
echo "Removed original file $source_file"
