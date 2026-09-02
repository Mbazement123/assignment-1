# Linux Diagnostic

A comprehensive suite of Bash scripts for system diagnostics, disk monitoring, and network connectivity analysis on Linux systems.

## Setup/Installation

1. **Clone or download the toolkit** to your desired directory:
   ```bash
   cd assignment-1
   ```

2. **Ensure all scripts are executable**:
   ```bash
   chmod +x *.sh
   ```

3. **Verify the logs directory exists**:
   ```bash
   mkdir -p logs
   ```

4. **Dependencies** (should be available on most Linux systems):
   - `bash` (version 4+)
   - Standard utilities: `uname`, `uptime`, `lscpu`, `free`, `df`, `ip`, `ping`, `curl`, `getent`, `dig`
   - For network testing: `nc` (netcat), `timeout` command

## Usage

### system-info.sh

Display comprehensive system information and log it for record-keeping.

**Usage:**
```bash
./system-info.sh
```

**Output:**
- Hostname
- Current user and working directory
- Current date and time
- Operating System and kernel version
- System uptime
- CPU information
- Memory usage
- Appends timestamped entry to `logs/system-info.log`

**Example:**
```bash
$ ./system-info.sh
=== System Information ===
Hostname: mycomputer
User: username
Working Directory: /home/username/assignment-1
Date/Time: Thu Sep  2 10:30:45 UTC 2026
OS: Ubuntu 22.04.1 LTS
Kernel: 5.15.0-56-generic
Uptime: 12 days, 3 hours
CPU Cores: 8
Memory: 15965 MB total, 8234 MB available
===

Log entry saved to logs/system-info.log
```

### disk-check.sh

Monitor disk usage against a threshold and report violations.

**Usage:**
```bash
./disk-check.sh <threshold> [path]
```

**Arguments:**
- `<threshold>` (required): Integer between 1-100 representing disk usage percentage threshold
- `[path]` (optional): Path to check disk usage for. Defaults to `/`

**Exit Codes:**
- `0`: Disk usage below threshold (success)
- `1`: Disk usage at or above threshold (alert)
- `2`: Invalid arguments or other error

**Examples:**
```bash
# Check root filesystem with 80% threshold
$ ./disk-check.sh 80
Disk Usage for '/': 45% (BELOW threshold of 80%)
Exit Code: 0

# Check home directory with 70% threshold
$ ./disk-check.sh 70 /home
Disk Usage for '/home': 82% (AT OR ABOVE threshold of 70%)
Exit Code: 1

# Invalid threshold
$ ./disk-check.sh 150
Error: Threshold must be an integer between 1 and 100
Exit Code: 2

# Check without threshold (missing argument)
$ ./disk-check.sh
Error: Threshold is required
Exit Code: 2
```

### network-check.sh

Perform comprehensive network diagnostics including DNS resolution, connectivity, and optional port testing.

**Usage:**
```bash
./network-check.sh <hostname-or-ip> [port]
```

**Arguments:**
- `<hostname-or-ip>` (required): Hostname or IP address to test
- `[port]` (optional): TCP port number (1-65535) to test connectivity

**Exit Codes:**
- `0`: Network tests passed
- `1`: Network connectivity failed or port unreachable
- `2`: Invalid arguments

An unresolvable hostname is reported as a connectivity failure and returns
exit code `1`; it is not treated as a direct IP address.

**Examples:**
```bash
# Check connectivity to a host
$ ./network-check.sh 8.8.8.8
Resolving 8.8.8.8 (8.8.8.8)...
Pinging 8.8.8.8...
PING Results: 3 packets transmitted, 3 received, 0% packet loss
Local Network Interfaces:
  eth0: 192.168.1.100/24
  lo: 127.0.0.1/8

# Check with specific port
$ ./network-check.sh google.com 443
Resolving google.com (172.217.14.206)...
Pinging 172.217.14.206...
Testing TCP port 443 on google.com...
Port 443 is reachable

# Invalid port
$ ./network-check.sh example.com 99999
Error: Port must be an integer between 1 and 65535
```

### grade.sh

Automated verification and grading of the diagnostic toolkit components.

**Usage:**
```bash
./grade.sh
```

**Output Example:**
```bash
=== GRADING SCRIPT ===
Checking required files... ✓
Checking executable permissions... ✓
Checking Bash syntax... ✓
Testing system-info.sh output... ✓
Testing disk-check.sh argument handling... ✓
Testing network-check.sh validation... ✓
Checking log file creation... ✓
Checking Git history... ✓
GRADE: PASS (8/8 checks passed)
```

## Git Workflow

This toolkit was developed using a feature-branch workflow:

```bash
# View branch history
git log --oneline --graph --all

# Check current branch
git branch -a
```

The project uses at least 2 branches (`main` and feature branches) with meaningful commit history tracking the development of each diagnostic component.

