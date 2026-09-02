#!/bin/bash

##############################################################################
# disk-check.sh - Disk Usage Monitoring Script
#
# Purpose: Monitor disk usage for a specified path against a threshold
#          and report status with logging
#
# Usage: ./disk-check.sh <threshold> [path]
#   threshold: Integer between 1-100 representing usage percentage threshold
#   path: File system path to check (default: /)
#
# Exit Codes:
#   0: Disk usage is below threshold (success)
#   1: Disk usage is at or above threshold (alert)
#   2: Invalid arguments or other error
##############################################################################

set -euo pipefail

# Script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/disk-check.log"

# Ensure logs directory exists
mkdir -p "${LOG_DIR}"

# Error handling
trap 'echo "Error: An unexpected error occurred in disk-check.sh" >&2; exit 2' ERR

##############################################################################
# Helper Functions
##############################################################################

# Validate threshold argument
validate_threshold() {
    local threshold="$1"
    
    # Check if threshold is provided
    if [[ -z "${threshold}" ]]; then
        echo "Error: Threshold is required" >&2
        return 2
    fi
    
    # Check if threshold is an integer
    if ! [[ "${threshold}" =~ ^[0-9]+$ ]]; then
        echo "Error: Threshold must be an integer" >&2
        return 2
    fi
    
    # Check if threshold is between 1 and 100
    if (( threshold < 1 || threshold > 100 )); then
        echo "Error: Threshold must be an integer between 1 and 100" >&2
        return 2
    fi
    
    return 0
}

# Get disk usage percentage for a path
get_disk_usage() {
    local path="$1"
    
    # Verify path exists
    if [[ ! -e "${path}" ]]; then
        echo "Error: Path does not exist: ${path}" >&2
        return 2
    fi
    
    # Get disk usage percentage using df
    if command -v df &> /dev/null; then
        df "${path}" | awk 'NR==2 {print $5}' | sed 's/%//'
    else
        echo "Error: df command not found" >&2
        return 2
    fi
}

##############################################################################
# Main Execution
##############################################################################

# Parse arguments
if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Error: Usage: ${0##*/} <threshold> [path]" >&2
    exit 2
fi

THRESHOLD="${1:-}"
PATH_TO_CHECK="${2:-.}"  # Default to current directory if not specified, but df will resolve to actual filesystem root

# Special case: if no path specified, use root filesystem
if [[ -z "${2:-}" ]]; then
    PATH_TO_CHECK="/"
fi

# Validate threshold
if ! validate_threshold "${THRESHOLD}"; then
    # Error message already printed by validate_threshold
    {
        echo "$(date '+%Y-%m-%d %H:%M:%S') | ERROR | Invalid threshold: ${THRESHOLD} | Path: ${PATH_TO_CHECK}"
    } >> "${LOG_FILE}"
    exit 2
fi

# Get current disk usage. Keep the command in a conditional because a
# non-zero result is an expected, handled error for an invalid path.
if ! USAGE=$(get_disk_usage "${PATH_TO_CHECK}"); then
    {
        echo "$(date '+%Y-%m-%d %H:%M:%S') | ERROR | Failed to get disk usage for ${PATH_TO_CHECK}"
    } >> "${LOG_FILE}"
    exit 2
fi

if ! [[ "${USAGE}" =~ ^[0-9]+$ ]]; then
    echo "Error: df returned an invalid disk usage value" >&2
    {
        echo "$(date '+%Y-%m-%d %H:%M:%S') | ERROR | Invalid disk usage value: ${USAGE} | Path: ${PATH_TO_CHECK}"
    } >> "${LOG_FILE}"
    exit 2
fi

# Display disk usage
echo "Disk Usage for '${PATH_TO_CHECK}': ${USAGE}%"

# Compare with threshold
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
if (( USAGE < THRESHOLD )); then
    echo "(BELOW threshold of ${THRESHOLD}%)"
    {
        echo "${TIMESTAMP} | OK | Usage: ${USAGE}% | Threshold: ${THRESHOLD}% | Path: ${PATH_TO_CHECK}"
    } >> "${LOG_FILE}"
    exit 0
else
    echo "(AT OR ABOVE threshold of ${THRESHOLD}%)"
    {
        echo "${TIMESTAMP} | ALERT | Usage: ${USAGE}% | Threshold: ${THRESHOLD}% | Path: ${PATH_TO_CHECK}"
    } >> "${LOG_FILE}"
    exit 1
fi
