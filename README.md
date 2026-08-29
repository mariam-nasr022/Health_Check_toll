# 🖥️ System Health & Performance Monitor

A Bash-based Linux tool that checks system performance, services, networking, system logs, and basic security.

## 📌 Overview

The script provides a quick health check of a Linux system and saves the results to a log file.

It checks:

* CPU and memory usage
* Disk space and I/O
* System uptime
* Services status
* Network connectivity and DNS
* System and hardware errors
* Failed services and login attempts
* Sudo users and pending updates

## ✨ Features

### 📊 System Monitoring

* CPU and memory usage
* Top resource-consuming processes
* Disk usage and I/O
* System uptime and boot time

### ⚙️ Services

Checks the status of important services such as:

```text
sshd
cron
apache2
mariadb
ufw
docker
```

The script reports whether each service is **active** and **enabled**.

### 🌐 Network & Security

* Network interfaces and gateway
* Internet connectivity and packet loss
* DNS and listening ports
* System and hardware errors
* Failed logins and services
* Sudo users and pending updates

## ⚙️ How It Works

1. Checks required commands and root privileges.
2. Initializes logging.
3. Collects performance information.
4. Checks services and network status.
5. Scans system logs and security information.
6. Removes old monitoring logs.

## 🚀 Usage

Make the script executable:

```bash
chmod +x monitor.sh
```

Run the system health check:

```bash
sudo ./monitor.sh
```

Display the help message:

```bash
./monitor.sh -h
```

> **Note:** The script must be run with root privileges because some system information and logs require administrative access.

## 📁 Logging

Each execution creates a timestamped log file in:

```text
/var/log/monitor
```

The log filename follows this format:

```text
health_YYYY-MM-DD_HH-MM.log
```

Example:

```text
health_2026-08-29_04-30.log
```

The script sends both standard output and errors to the log file while also displaying them on the terminal.

## 🚨 Thresholds

The script uses configurable thresholds to detect potential problems:

| Check         | Threshold |
| ------------- | --------: |
| CPU Usage     |       80% |
| Memory Usage  |       80% |
| Disk Usage    |       90% |
| Packet Loss   |       20% |
| Log Retention |    7 days |
| Top Processes |         6 |

The script displays a warning when CPU, memory, disk usage, or packet loss exceeds its threshold.

## 🛡️ Error Handling

The script checks for required commands and root privileges before running. Missing dependencies or insufficient permissions stop the script with an error message.

## 🛠️ Technologies

* Bash
* Linux
* `systemctl`
* `journalctl`
* `ps`
* `df`
* `free`
* `ip`
* `ping`
* `iostat`

## 📂 Project Structure

```text
Health_Check_toll/
├── monitor.sh
└── README.md
```

## ⚙️ Configuration

The main configuration variables can be adjusted inside `monitor.sh`:

```bash
Log_Dir="/var/log/monitor"
Log_File="${Log_Dir}/health_$(date +%Y-%m-%d_%H-%M).log"

THRESHOLD_CPU=80
THRESHOLD_MEM=80
THRESHOLD_DISK=90
THRESHOLD_PACKET_LOSS=20

Log_Retention_Days=7
TOP_N=6
```

## 👩‍💻 Author

**Mariam Nasr**

**Version:** 1.0

