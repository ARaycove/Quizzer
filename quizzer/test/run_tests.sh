#!/bin/bash

# Import line count functions
source "$(dirname "$0")/line_count_functions.sh"

# Check for starting test number argument
START_TEST_NUM=""
if [ $# -eq 1 ]; then
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        START_TEST_NUM="$1"
        echo -e "${BLUE}=== Quizzer Test Runner (Starting from test $START_TEST_NUM) ===${NC}"
    else
        echo -e "${RED}Error: Argument must be a number${NC}"
        echo "Usage: $0 [test_number]"
        echo "Example: $0 11 (starts from test_11_*)"
        exit 1
    fi
else
    echo -e "${BLUE}=== Quizzer Test Runner ===${NC}"
fi
echo ""

# Initialize counters
total_tests=0
passed_tests=0
failed_tests=0
skipped_tests=0

# Arrays to store results
declare -a passed_files
declare -a failed_files
declare -a skipped_files
declare -a test_times

# Find all test files matching the pattern test_##_*.dart and sort them numerically
test_files=$(find . -name "test_*.dart" | grep -E "test_[0-9]+_.*\.dart" | sort -V)

if [ -z "$test_files" ]; then
    echo -e "${YELLOW}No test files found matching pattern test_##_*.dart${NC}"
    exit 1
fi

# Filter test files if starting from a specific test number
if [ -n "$START_TEST_NUM" ]; then
    # Filter to only include tests starting from the specified number
    filtered_test_files=""
    for test_file in $test_files; do
        test_number=$(basename "$test_file" .dart | grep -o 'test_[0-9]*' | sed 's/test_//')
        if [ "$test_number" -ge "$START_TEST_NUM" ]; then
            filtered_test_files="$filtered_test_files $test_file"
        fi
    done
    test_files="$filtered_test_files"
    
    if [ -z "$test_files" ]; then
        echo -e "${YELLOW}No test files found starting from test number $START_TEST_NUM${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Found test files (starting from test $START_TEST_NUM):${NC}"
else
    echo -e "${BLUE}Found test files:${NC}"
fi
echo "$test_files" | sed 's|^\./||'
echo ""

# 1. Comprehensive breakdown of line counts
print_line_count_report

# Run each test file
for test_file in $test_files; do
    # Extract the test number and name for display
    test_name=$(basename "$test_file" .dart)
    test_number=$(echo "$test_name" | grep -o 'test_[0-9]*' | sed 's/test_//')
    
    echo -e "${BLUE}[$test_number] Running: $test_name${NC}"
    
    # Record start time
    start_time=$(date +%s.%N)
    
    # Run the test and capture output and exit code
    output=$(flutter test "$test_file" 2>&1)
    exit_code=$?
    
    # Record end time and calculate duration
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    test_times+=("$duration")
    
    # Check if test passed, failed, or was skipped
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED${NC} (${duration}s)"
        passed_tests=$((passed_tests + 1))
        passed_files+=("$test_name")
    else
        # Check if it was skipped (no tests found)
        if echo "$output" | grep -q "No tests found"; then
            echo -e "${YELLOW}⚠ SKIPPED (No tests found)${NC} (${duration}s)"
            skipped_tests=$((skipped_tests + 1))
            skipped_files+=("$test_name")
        else
            echo -e "${RED}✗ FAILED${NC} (${duration}s)"
            failed_tests=$((failed_tests + 1))
            failed_files+=("$test_name")
            
            # Display failure reason
            echo -e "${RED}Failure Details:${NC}"
            echo "----------------------------------------"
            
            # Extract and display the failure reason
            # Look for common failure patterns in Flutter test output
            failure_reason=$(echo "$output" | grep -E "(FAILED|ERROR|Exception|Error:|Failed assertion|Expected:|Actual:)" | head -5)
            
            if [ -n "$failure_reason" ]; then
                echo -e "${RED}$failure_reason${NC}" | sed 's/^/  /'
            else
                # If no specific failure reason found, show the last few lines of output
                echo -e "${RED}Last few lines of test output:${NC}"
                echo "$output" | tail -10 | sed 's/^/  /'
            fi
            
            echo "----------------------------------------"
            
            # TERMINATE EARLY: Exit immediately if any test fails
            echo -e "${RED}❌ Test failed! Terminating test sequence.${NC}"
            echo ""
            echo -e "${BLUE}=== Partial Test Summary ===${NC}"
            echo -e "Tests run: $total_tests"
            echo -e "${GREEN}Passed: $passed_tests${NC}"
            echo -e "${RED}Failed: $failed_tests${NC}"
            echo -e "${YELLOW}Skipped: $skipped_tests${NC}"
            echo ""
            echo -e "${RED}❌ Test sequence terminated due to failure.${NC}"
            exit 1
        fi
    fi
    
    total_tests=$((total_tests + 1))
    echo ""
done

# Print summary report
echo -e "${BLUE}=== Test Summary Report ===${NC}"
echo ""

# Calculate total time
total_time=0
for time in "${test_times[@]}"; do
    total_time=$(echo "$total_time + $time" | bc -l)
done

echo -e "Total tests run: $total_tests"
echo -e "Total time: ${total_time}s"
echo -e "${GREEN}Passed: $passed_tests${NC}"
echo -e "${RED}Failed: $failed_tests${NC}"
echo -e "${YELLOW}Skipped: $skipped_tests${NC}"
echo ""

# Print detailed results as a table
echo -e "${BLUE}Detailed Results:${NC}"
echo ""

# Print table header
printf "%-35s %-10s %-10s\n" "Test Name" "Status" "Time (s)"
echo "----------------------------------------------------------------"

# Function to print a test row
print_test_row() {
    local test_name="$1"
    local status="$2"
    local time="$3"
    local color="$4"
    
    # Truncate test name if too long
    if [ ${#test_name} -gt 32 ]; then
        test_name="${test_name:0:29}..."
    fi
    
    # Round time to 2 decimal places
    rounded_time=$(printf "%.2f" "$time")
    
    # Use echo -e for proper color handling and printf for alignment
    printf "%-35s " "$test_name"
    echo -en "$color"
    printf "%-10s" "$status"
    echo -en "$NC"
    printf " %-10s\n" "$rounded_time"
}

# Print all tests in order
test_index=0
for test_file in $test_files; do
    test_name=$(basename "$test_file" .dart)
    time="${test_times[$test_index]}"
    
    # Determine status and color
    if [[ " ${passed_files[@]} " =~ " ${test_name} " ]]; then
        status="PASS"
        color="$GREEN"
    elif [[ " ${failed_files[@]} " =~ " ${test_name} " ]]; then
        status="FAIL"
        color="$RED"
    elif [[ " ${skipped_files[@]} " =~ " ${test_name} " ]]; then
        status="SKIP"
        color="$YELLOW"
    fi
    
    print_test_row "$test_name" "$status" "$time" "$color"
    test_index=$((test_index + 1))
done

echo ""

# Final status
if [ $failed_tests -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
else
    echo -e "${RED}❌ Some tests failed!${NC}"
fi

# 3. Final Line Count Report
print_line_count_report

# Final exit code
if [ $failed_tests -eq 0 ]; then
    exit 0
else
    exit 1
fi 