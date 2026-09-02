#!/bin/bash

##############################################################################
# network-check.sh - Network Connectivity and Diagnostics Script
#
# Purpose: Perform comprehensive network diagnostics including DNS resolution,
#          connectivity testing, interface enumeration, and optional TCP port
#          testing
#
# Usage: ./network-check.sh <hostname-or-ip> [port]
#   hostname-or-ip: Hostname or IP address to test (required)
#   port: TCP port number (1-65535) to test connectivity (optional)
#
# Exit Codes:
#   0: Network tests passed
#   1: Network connectivity failed or port unreachable
#   2: Invalid arguments
##############################################################################

set -euo pipefail

# Script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/network-check.log"

# Ensure logs directory exists
mkdir -p "${LOG_DIR}"

# Error handling
trap 'echo "Error: An unexpected error occurred in network-check.sh" >&2; exit 2' ERR

##############################################################################
# Helper Functions
##############################################################################

# Validate hostname/IP argument
validate_host() {
    local host="$1"
    
    if [[ -z "${host}" ]]; then
        echo "Error: Hostname or IP address is required" >&2
        return 2
    fi
    
    return 0
}

# Validate port argument
validate_port() {
    local port="$1"
    
    # Check if port is provided
    if [[ -z "${port}" ]]; then
        return 0  # Port is optional
    fi
    
    # Check if port is an integer
    if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
        echo "Error: Port must be an integer" >&2
        return 2
    fi
    
    # Check if port is between 1 and 65535
    if (( port < 1 || port > 65535 )); then
        echo "Error: Port must be an integer between 1 and 65535" >&2
        return 2
    fi
    
    return 0
}

# Resolve hostname to IP address
resolve_host() {
    local host="$1"
    local resolved_ip=""
    
    # Try using getent first (faster and more portable)
    if command -v getent &> /dev/null; then
        resolved_ip=$(getent hosts "${host}" 2>/dev/null | awk '{print $1}' | head -n1)
    fi
    
    # Fallback to dig if getent fails
    if [[ -z "${resolved_ip}" ]] && command -v dig &> /dev/null; then
        resolved_ip=$(dig +short "${host}" A 2>/dev/null | head -n1)
    fi
    
    # Fallback to nslookup if dig fails
    if [[ -z "${resolved_ip}" ]] && command -v nslookup &> /dev/null; then
        resolved_ip=$(nslookup "${host}" 2>/dev/null | grep "Address:" | tail -n1 | awk '{print $NF}')
    fi
    
    # Direct IPv4 addresses and localhost do not require DNS resolution.
    if [[ -z "${resolved_ip}" ]]; then
        if [[ "${host}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ || "${host}" == "localhost" ]]; then
            resolved_ip="${host}"
        else
            echo "Error: Unable to resolve host: ${host}" >&2
            return 1
        fi
    fi
    
    echo "${resolved_ip}"
}

# Perform ping connectivity test
test_ping() {
    local ip="$1"
    
    if ! command -v ping &> /dev/null; then
        echo "Warning: ping command not found" >&2
        return 1
    fi
    
    # Send 3 ping packets with 2 second timeout per packet
    if ping -c 3 -W 2 "${ip}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get local network interfaces
get_network_interfaces() {
    if command -v ip &> /dev/null; then
        ip addr | grep -E '^\d+:' -A 1 | grep "inet" | awk '{print $NF ":" $2}' | sed 's/<[^>]*>//'
    elif command -v ifconfig &> /dev/null; then
        ifconfig | grep -E "^\w+" | awk '{print $1}' | while read -r iface; do
            inet=$(ifconfig "${iface}" 2>/dev/null | grep "inet " | awk '{print $2}')
            if [[ -n "${inet}" ]]; then
                echo "${iface}: ${inet}"
            fi
        done
    else
        echo "Unable to determine network interfaces"
        return 1
    fi
}

# Test TCP connectivity to a port
test_tcp_port() {
    local host="$1"
    local ip="$2"
    local port="$3"
    
    # Try using timeout with bash TCP socket
    if (timeout 3 bash -c "</dev/tcp/${ip}/${port}" &>/dev/null) 2>/dev/null; then
        return 0
    fi
    
    # Fallback to nc (netcat)
    if command -v nc &> /dev/null; then
        if nc -zv -w 2 "${ip}" "${port}" &>/dev/null; then
            return 0
        fi
    fi
    
    # Fallback to curl (verbose, will show if connection succeeds)
    if command -v curl &> /dev/null; then
        if timeout 3 curl -m 3 --connect-timeout 2 "http://${ip}:${port}" &>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

##############################################################################
# Main Execution
##############################################################################

# Parse arguments
if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Error: Usage: ${0##*/} <hostname-or-ip> [port]" >&2
    exit 2
fi

HOST="${1:-}"
PORT="${2:-}"

# Validate arguments
if ! validate_host "${HOST}"; then
    {
        echo "$(date '+%Y-%m-%d %H:%M:%S') | ERROR | Missing hostname or IP address"
    } >> "${LOG_FILE}"
    exit 2
fi

if ! validate_port "${PORT}"; then
    {
        echo "$(date '+%Y-%m-%d %H:%M:%S') | ERROR | Invalid port: ${PORT}"
    } >> "${LOG_FILE}"
    exit 2
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
OVERALL_STATUS=0

# Display header
echo "=== Network Diagnostics for '${HOST}' ==="
echo

# Step 1: Resolve hostname to IP
echo "Resolving ${HOST}..."
if ! RESOLVED_IP=$(resolve_host "${HOST}"); then
    {
        echo "${TIMESTAMP} | ERROR | Unable to resolve host: ${HOST}"
    } >> "${LOG_FILE}"
    exit 1
fi

if [[ -n "${RESOLVED_IP}" && "${RESOLVED_IP}" != "localhost" ]]; then
    echo "  Resolved to: ${RESOLVED_IP}"
else
    echo "  Resolved to: ${RESOLVED_IP}"
fi
echo

# Step 2: Ping connectivity test
echo "Pinging ${RESOLVED_IP}..."
if test_ping "${RESOLVED_IP}"; then
    echo "  ✓ Ping successful (host is reachable)"
    PING_STATUS="OK"
else
    echo "  ✗ Ping failed (host may be unreachable)"
    PING_STATUS="FAILED"
    OVERALL_STATUS=1
fi
echo

# Step 3: Display local network interfaces
echo "Local Network Interfaces:"
if get_network_interfaces | while read -r interface; do
    echo "  ${interface}"
done; then
    :
else
    echo "  (Unable to retrieve network interface information)"
fi
echo

# Step 4: Test TCP port if specified
if [[ -n "${PORT}" ]]; then
    echo "Testing TCP port ${PORT} on ${RESOLVED_IP}..."
    if test_tcp_port "${HOST}" "${RESOLVED_IP}" "${PORT}"; then
        echo "  ✓ Port ${PORT} is reachable"
        PORT_STATUS="OK"
    else
        echo "  ✗ Port ${PORT} is not reachable or filtered"
        PORT_STATUS="FAILED"
        OVERALL_STATUS=1
    fi
    echo
    
    # Log detailed entry with port
    {
        echo "${TIMESTAMP} | STATUS: $([ ${OVERALL_STATUS} -eq 0 ] && echo "OK" || echo "FAILED") | Host: ${HOST} | IP: ${RESOLVED_IP} | Ping: ${PING_STATUS} | Port ${PORT}: ${PORT_STATUS}"
    } >> "${LOG_FILE}"
else
    # Log detailed entry without port
    {
        echo "${TIMESTAMP} | STATUS: $([ ${OVERALL_STATUS} -eq 0 ] && echo "OK" || echo "FAILED") | Host: ${HOST} | IP: ${RESOLVED_IP} | Ping: ${PING_STATUS}"
    } >> "${LOG_FILE}"
fi

echo "==="
echo "Network diagnostics log saved to ${LOG_FILE}"

exit ${OVERALL_STATUS}
