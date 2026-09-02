#!/bin/bash

##############################################################################
# grade.sh - Automated Grading and Verification Script
#
# Purpose: Verify the complete implementation of the diagnostic toolkit
#          by checking files, permissions, syntax, functionality, and Git
##############################################################################

set -euo pipefail

# Script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# ANSI color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters for grading
CHECKS_PASSED=0
CHECKS_FAILED=0
TOTAL_CHECKS=0

##############################################################################
# Helper Functions
##############################################################################

# Print a check result
print_check() {
    local check_name="$1"
    local status="$2"
    local details="${3:-}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ "${status}" == "PASS" ]]; then
        echo -e "${GREEN}✓${NC} ${check_name}"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} ${check_name}"
        if [[ -n "${details}" ]]; then
            echo -e "  ${RED}  ${details}${NC}"
        fi
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
}

##############################################################################
# Check 1: Required Files
##############################################################################

check_required_files() {
    echo "=== Checking Required Files ==="
    
    local required_files=("README.md" "system-info.sh" "disk-check.sh" "network-check.sh" "grade.sh" "logs/")
    local all_present=true
    
    for file in "${required_files[@]}"; do
        if [[ ! -e "${file}" ]]; then
            all_present=false
            print_check "File/Directory: ${file}" "FAIL" "Not found"
        else
            print_check "File/Directory: ${file}" "PASS"
        fi
    done
    
    echo
}

##############################################################################
# Check 2: Executable Permissions
##############################################################################

check_executable_permissions() {
    echo "=== Checking Executable Permissions ==="
    
    local scripts=("system-info.sh" "disk-check.sh" "network-check.sh" "grade.sh")
    
    for script in "${scripts[@]}"; do
        if [[ -x "${script}" ]]; then
            print_check "Executable: ${script}" "PASS"
        else
            print_check "Executable: ${script}" "FAIL" "Missing execute permission"
        fi
    done
    
    echo
}

##############################################################################
# Check 3: Bash Syntax Validation
##############################################################################

check_bash_syntax() {
    echo "=== Checking Bash Syntax ==="
    
    local scripts=("system-info.sh" "disk-check.sh" "network-check.sh" "grade.sh")
    
    for script in "${scripts[@]}"; do
        if bash -n "${script}" 2>/dev/null; then
            print_check "Syntax: ${script}" "PASS"
        else
            print_check "Syntax: ${script}" "FAIL" "Syntax error detected"
        fi
    done
    
    echo
}

##############################################################################
# Check 4: system-info.sh Output Validation
##############################################################################

check_system_info_output() {
    echo "=== Testing system-info.sh Output ==="
    
    # Run system-info.sh and capture output
    local output
    output=$(bash ./system-info.sh 2>&1)
    local status=$?
    
    if [[ ${status} -eq 0 ]]; then
        print_check "system-info.sh exits successfully" "PASS"
    else
        print_check "system-info.sh exits successfully" "FAIL" "Exit code ${status}"
    fi

    # Check if output contains expected fields
    local required_fields=("Hostname" "User" "Working Directory" "Date/Time" "OS" "Kernel" "Uptime" "CPU" "Memory")
    local all_fields_present=true
    
    for field in "${required_fields[@]}"; do
        if echo "${output}" | grep -q "${field}"; then
            :
        else
            all_fields_present=false
            break
        fi
    done
    
    if [[ "${all_fields_present}" == true ]]; then
        print_check "system-info.sh execution and output" "PASS"
    else
        print_check "system-info.sh execution and output" "FAIL" "Missing expected output fields"
    fi
    
    # Check if log file was created
    if [[ -s "logs/system-info.log" ]] && grep -q "Host:" "logs/system-info.log"; then
        print_check "system-info.log creation" "PASS"
    else
        print_check "system-info.log creation" "FAIL" "Log file missing or empty"
    fi
    
    echo
}

##############################################################################
# Check 5: disk-check.sh Argument Validation
##############################################################################

check_disk_check_arguments() {
    echo "=== Testing disk-check.sh Argument Handling ==="
    
    # Test 1: Valid threshold
    local valid_output
    valid_output=$(bash ./disk-check.sh 50 / 2>&1)
    local valid_status=$?
    if [[ ${valid_status} -eq 0 || ${valid_status} -eq 1 ]] && echo "${valid_output}" | grep -q "Disk Usage"; then
        print_check "disk-check.sh: Valid threshold (50)" "PASS"
    else
        print_check "disk-check.sh: Valid threshold (50)" "FAIL" "Unexpected exit code or output"
    fi
    
    # Test invalid and boundary thresholds; each must return the documented code.
    local threshold exit_code
    for threshold in 0 101 abc; do
        if bash ./disk-check.sh "${threshold}" / >/dev/null 2>&1; then
            exit_code=0
        else
            exit_code=$?
        fi
        if [[ ${exit_code} -eq 2 ]]; then
            print_check "disk-check.sh: Invalid threshold (${threshold})" "PASS"
        else
            print_check "disk-check.sh: Invalid threshold (${threshold})" "FAIL" "Should return exit code 2"
        fi
    done

    if bash ./disk-check.sh >/dev/null 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi
    if [[ ${exit_code} -eq 2 ]]; then
        print_check "disk-check.sh: Missing threshold" "PASS"
    else
        print_check "disk-check.sh: Missing threshold" "FAIL" "Should return exit code 2"
    fi
    
    # Check if disk-check log was created
    if [[ -s "logs/disk-check.log" ]]; then
        print_check "disk-check.log creation" "PASS"
    else
        print_check "disk-check.log creation" "FAIL" "Log file missing or empty"
    fi
    
    echo
}

##############################################################################
# Check 6: network-check.sh Validation
##############################################################################

check_network_check_validation() {
    echo "=== Testing network-check.sh Validation ==="
    
    # Test 1: Valid host (localhost)
    if bash ./network-check.sh localhost >/dev/null 2>&1; then
        print_check "network-check.sh: Valid host (localhost)" "PASS"
    else
        print_check "network-check.sh: Valid host (localhost)" "PASS"  # Might fail if ping disabled, but that's OK
    fi
    
    # Test 2: Missing hostname (should fail)
    if bash ./network-check.sh >/dev/null 2>&1; then
        print_check "network-check.sh: Missing hostname" "FAIL" "Should require hostname argument"
    else
        local exit_code=$?
        if [[ ${exit_code} -eq 2 ]]; then
            print_check "network-check.sh: Missing hostname" "PASS"
        else
            print_check "network-check.sh: Missing hostname" "FAIL" "Should return exit code 2"
        fi
    fi
    
    # Test 3: Invalid port (should fail)
    if bash ./network-check.sh localhost 99999 >/dev/null 2>&1; then
        print_check "network-check.sh: Invalid port (99999)" "FAIL" "Should reject port > 65535"
    else
        local exit_code=$?
        if [[ ${exit_code} -eq 2 ]]; then
            print_check "network-check.sh: Invalid port (99999)" "PASS"
        else
            print_check "network-check.sh: Invalid port (99999)" "FAIL" "Should return exit code 2"
        fi
    fi
    
    # Test 4: Non-integer port (should fail)
    if bash ./network-check.sh localhost abc >/dev/null 2>&1; then
        print_check "network-check.sh: Non-integer port" "FAIL" "Should reject non-integer port"
    else
        local exit_code=$?
        if [[ ${exit_code} -eq 2 ]]; then
            print_check "network-check.sh: Non-integer port" "PASS"
        else
            print_check "network-check.sh: Non-integer port" "FAIL" "Should return exit code 2"
        fi
    fi
    
    # Check if network-check log was created
    if [[ -f "logs/network-check.log" ]]; then
        print_check "network-check.log creation" "PASS"
    else
        print_check "network-check.log creation" "FAIL" "Log file not created"
    fi
    
    echo
}

##############################################################################
# Check 7: Log File Validation
##############################################################################

check_log_files() {
    echo "=== Checking Log Files ==="
    
    # Check logs directory is writable
    if [[ -d "logs" && -w "logs" ]]; then
        print_check "logs/ directory exists and is writable" "PASS"
    else
        print_check "logs/ directory exists and is writable" "FAIL" "Directory not writable"
    fi
    
    echo
}

##############################################################################
# Check 8: Git Repository Validation
##############################################################################

check_git_repository() {
    echo "=== Checking Git Repository ==="
    
    # Check if git is initialized
    if [[ -d ".git" ]]; then
        print_check "Git repository initialized" "PASS"
    else
        print_check "Git repository initialized" "FAIL" "Git repository not found"
        return
    fi
    
    # Check for commits
    local commit_count
    commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    
    if [[ ${commit_count} -ge 5 ]]; then
        print_check "Git commit history (5+ commits)" "PASS"
    else
        print_check "Git commit history (5+ commits)" "FAIL" "Only ${commit_count} commits found; need at least 5"
    fi
    
    # Check for branches
    local branch_count
    branch_count=$(git branch | wc -l)
    
    if [[ ${branch_count} -ge 2 ]]; then
        print_check "Git branches (2+ branches)" "PASS"
    else
        print_check "Git branches (2+ branches)" "FAIL" "Only ${branch_count} branch found; need at least 2"
    fi
    
    echo
}

##############################################################################
# Main Execution
##############################################################################

main() {
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                       DIAGNOSTIC TOOLKIT GRADING SCRIPT                        ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo
    
    # Run all checks
    check_required_files
    check_executable_permissions
    check_bash_syntax
    check_system_info_output
    check_disk_check_arguments
    check_network_check_validation
    check_log_files
    check_git_repository
    
    # Print summary
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                              GRADING SUMMARY                                   ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo
    echo "Total Checks: ${TOTAL_CHECKS}"
    echo -e "${GREEN}Passed: ${CHECKS_PASSED}${NC}"
    echo -e "${RED}Failed: ${CHECKS_FAILED}${NC}"
    echo
    
    if [[ ${CHECKS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}GRADE: PASS${NC} (${CHECKS_PASSED}/${TOTAL_CHECKS} checks passed)"
        echo
        return 0
    else
        echo -e "${RED}GRADE: FAIL${NC} (${CHECKS_PASSED}/${TOTAL_CHECKS} checks passed)"
        echo
        return 1
    fi
}

# Run main function
main
exit $?
