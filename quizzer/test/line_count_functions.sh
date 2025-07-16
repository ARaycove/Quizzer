#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to count lines in a file
count_lines_in_file() {
    local file="$1"
    if [ -f "$file" ]; then
        wc -l < "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to count lines in all .dart files in a directory recursively
count_lines_in_directory() {
    local dir="$1"
    local total=0
    
    if [ ! -d "$dir" ]; then
        return 0
    fi
    
    # Count lines in .dart files in current directory
    for file in "$dir"/*.dart; do
        if [ -f "$file" ]; then
            local lines=$(count_lines_in_file "$file")
            total=$((total + lines))
        fi
    done
    
    # Recursively count in subdirectories
    for subdir in "$dir"/*/; do
        if [ -d "$subdir" ]; then
            local sublines=$(count_lines_in_directory "$subdir")
            total=$((total + sublines))
        fi
    done
    
    echo $total
}

# Function to print directory tree with proper formatting
print_directory_tree() {
    local dir="$1"
    local dirname="$2"
    
    echo -e "${BLUE}--- $dirname Breakdown (recursive, alphabetical) ---${NC}"
    
    # Recursively build the full tree structure
    print_directory_recursive "$dir" ""
}

# Helper function to recursively print directory tree
print_directory_recursive() {
    local dir="$1"
    local indent="$2"
    
    # Get all subdirectories and sort them
    local subdirs=()
    for subdir in "$dir"/*/; do
        if [ -d "$subdir" ]; then
            subdirs+=("$subdir")
        fi
    done
    
    # Sort subdirectories alphabetically
    IFS=$'\n' subdirs=($(sort <<<"${subdirs[*]}"))
    unset IFS
    
    # Process each subdirectory
    for subdir in "${subdirs[@]}"; do
        local subname=$(basename "$subdir")
        local sublines=$(count_lines_in_directory "$subdir")
        printf "%s├── %-40s %6d\n" "$indent" "$subname/" "$sublines"
        
        # Recursively process subdirectories
        print_directory_recursive "$subdir" "$indent    "
    done
}

# Function to print line count report
print_line_count_report() {
    local backend_lines=$(count_lines_in_directory "lib/backend_systems")
    local ui_lines=$(count_lines_in_directory "lib/UI_systems")
    local test_lines=$(count_lines_in_directory "test")
    
    local total_lines=$((backend_lines + ui_lines + test_lines))
    
    echo -e "${BLUE}=== Line Count Report ===${NC}"
    echo ""
    echo -e "${BLUE}--- Line Count Summary ---${NC}"
    printf "%-25s %6d\n" "Total_Backend_Systems:" "$backend_lines"
    printf "%-25s %6d\n" "Total_UI_Systems:" "$ui_lines"
    printf "%-25s %6d\n" "Total_Test_Lines:" "$test_lines"
    echo "--------------------------"
    printf "%-25s %6d\n" "Total_Lines:" "$total_lines"
    echo "--------------------------"
    
    # Print backend systems breakdown
    print_directory_tree "lib/backend_systems" "Backend Systems"
    
    # Print UI systems breakdown
    print_directory_tree "lib/UI_systems" "UI Systems"
    
    echo ""
}

# If this script is run directly (not sourced), call the main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    print_line_count_report
fi 