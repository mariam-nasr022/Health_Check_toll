System Health & Performance Monitor

A comprehensive Bash script for monitoring Linux system health and performance.
The script collects important system information, performs health checks, detects warnings, and saves detailed reports into log files.

---

Features

System Information

- System uptime
- Last boot time

CPU Monitoring

- Current CPU usage percentage
- Top CPU-consuming processes
- CPU threshold alerts

Memory Monitoring

- Current memory usage percentage
- Top memory-consuming processes
- Memory threshold alerts

Disk Monitoring

- Disk space usage
- Disk threshold alerts
- Disk I/O statistics

Services Check

Checks important services such as:

- SSH ("sshd")
- Cron ("cron")
- Apache ("apache2")
- MariaDB ("mariadb")
- UFW Firewall ("ufw")
- Docker ("docker")

Shows:

- Active status
- Enabled status

Network Check

- Network interfaces
- Default gateway
- Internet connectivity test
- Packet loss detection
- DNS resolution test
- Listening ports
- Network traffic statistics

System Logs Analysis

Detects:

- Boot errors
- OOM (Out Of Memory) kills
- Disk warnings
- Hardware errors
- Driver issues
- Failed services

Security Check

- Failed login attempts
- Users with sudo privileges
- Pending package updates

Logging

- Automatically creates log files
- Stores reports in:

/var/log/monitor/

- Automatic cleanup of old logs

---

Requirements

Install the following packages before running the script:

Ubuntu / Debian

sudo apt update

sudo apt install sysstat bc dnsutils iproute2 iputils-ping \
net-tools util-linux systemd

---

Script Variables

Variable| Description
"THRESHOLD_CPU"| CPU warning threshold
"THRESHOLD_MEM"| Memory warning threshold
"THRESHOLD_DISK"| Disk usage threshold
"THRESHOLD_PACKET_LOSS"| Network packet loss threshold
"Log_Retention_Days"| Number of days to keep logs
"TOP_N"| Number of top processes displayed

---

Installation

Clone the repository:

git clone https://github.com/mariam-nasr022/system-health-monitor.git

Move into the directory:

cd system-health-monitor

Make the script executable:

chmod +x monitor.sh

---

Usage

Run the script:

sudo ./monitor.sh

Display help:

./monitor.sh -h

---

Example Output

====================================
             CPU Usage
====================================

CPU Usage: 15.7%

Top CPU-Consuming Processes:
USER      PID   %CPU   COMMAND
root      325   10.2   apache2
mysql     512    8.4   mariadb

---

Log Files

Generated reports are saved as:

/var/log/monitor/health_YYYY-MM-DD_HH-MM.log

Example:

/var/log/monitor/health_2026-08-29_15-30.log

---

Error Handling

The script checks:

- Required commands availability
- Root privileges
- Missing dependencies
- Invalid options

---

Future Improvements

- Export reports to HTML
- Email alerts
- JSON report generation
- Dashboard integration
- Monitoring multiple servers

---

Author

Mariam Nasr


