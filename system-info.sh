#!/bin/bash

##############################################################################
# system-info.sh - Comprehensive System Information Reporter
#
# Purpose: Display and log detailed system metrics including hostname,
#          user, OS information, kernel version, uptime, CPU, and memory
#
# Usage: ./system-info.sh
#
# Exit Codes:
#   0: Successfully displayed and logged system information
#   1: Error during execution
##############################################################################

set -euo pipefail

# Script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/system-info.log"

# Ensure logs directory exists
mkdir -p "${LOG_DIR}"

# Error handling
trap 'echo "Error: An unexpected error occurred in system-info.sh" >&2; exit 1' ERR

##############################################################################
# Helper Functions
##############################################################################

# Get OS information from /etc/os-release or lsb_release
get_os_info() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${PRETTY_NAME:-${NAME:-Unknown}}"
    elif command -v lsb_release &> /dev/null; then
        lsb_release -d | cut -f2
    else
        echo "Unknown Linux Distribution"
    fi
}

# Get CPU information
get_cpu_info() {
    if command -v lscpu &> /dev/null; then
        # Get number of CPU cores
        lscpu | grep "^CPU(s):" | awk '{print $2}'
    elif [[ -f /proc/cpuinfo ]]; then
        grep -c "^processor" /proc/cpuinfo
    else
        echo "0"
    fi
}

# Get memory information
get_memory_info() {
    if command -v free &> /dev/null; then
        free -h | awk '/^Mem:/ {printf "%s total, %s available", $2, $7}'
    elif [[ -f /proc/meminfo ]]; then
        local total=$(awk '/^MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)
        local available=$(awk '/^MemAvailable:/ {printf "%d", $2/1024}' /proc/meminfo)
        echo "${total} MB total, ${available} MB available"
    else
        echo "Unknown"
    fi
}

##############################################################################
# Main Execution
##############################################################################

if [[ $# -ne 0 ]]; then
    echo "Error: Usage: ${0##*/}" >&2
    exit 2
fi

# Collect system information
HOSTNAME=$(hostname)
CURRENT_USER=$(whoami)
CURRENT_DATE=$(date)
CURRENT_PWD=$(pwd)
OS_INFO=$(get_os_info)
KERNEL_VERSION=$(uname -r)
UPTIME=$(uptime | sed 's/^[^,]*, //' | xargs)  # Remove "current time," prefix
CPU_CORES=$(get_cpu_info)
MEMORY_INFO=$(get_memory_info)

# Display formatted output
echo "=== System Information ==="
echo "Hostname: ${HOSTNAME}"
echo "User: ${CURRENT_USER}"
echo "Working Directory: ${CURRENT_PWD}"
echo "Date/Time: ${CURRENT_DATE}"
echo "OS: ${OS_INFO}"
echo "Kernel: ${KERNEL_VERSION}"
echo "Uptime: ${UPTIME}"
echo "CPU Cores: ${CPU_CORES}"
echo "Memory: ${MEMORY_INFO}"
echo "==="
echo

# Create timestamped log entry
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_ENTRY="${TIMESTAMP} | Host: ${HOSTNAME} | User: ${CURRENT_USER} | OS: ${OS_INFO} | Kernel: ${KERNEL_VERSION} | Uptime: ${UPTIME} | CPUs: ${CPU_CORES} | Memory: ${MEMORY_INFO}"

# Append to log file
{
    echo "${LOG_ENTRY}"
} >> "${LOG_FILE}"

echo "Log entry saved to ${LOG_FILE}"

exit 0
