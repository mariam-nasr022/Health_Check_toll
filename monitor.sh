#!/bin/bash
#
# Script Name : monitor.sh
# Description: A Bash script that performs a basic system health check by monitoring
#	       CPU and memory usage, disk space and I/O, network connectivity, 
# 	       running services, system logs, and basic security information.
#   	       It also highlights common issues, saves the results to log files,
#   	        and removes old logs automatically.
#
# Usage : ./monitor.sh
# Author : Mariam Nasr
# Version : 1.0



# Variables

Log_Dir="/var/log/monitor"
Log_File="${Log_Dir}/health_$(date +%Y-%m-%d_%H-%M).log"
SERVICES=("sshd" "cron" "apache2" "mariadb" "ufw" "docker")

THRESHOLD_CPU=80
THRESHOLD_MEM=80
THRESHOLD_DISK=90
THRESHOLD_PACKET_LOSS=20
Log_Retention_Days=7
TOP_N=6


# Reject any unknown option (anything other than -h)

if [[ -n "$1" && "$1" != "-h" ]]; then
    echo "Error: Unknown option '$1'" >&2
    echo "Try '$0 -h' for more information." >&2
    exit 1
fi



# Functions


# Displays help/usage information for the script

show_help() {
    echo "System Health & Performance Check"
    echo "=================================="
    echo "Description: Collects and reports on system health -"
    echo "             Uptime, CPU, Memory, Disk, Services, Network,"
    echo "             Syslogs, and Security checks."
    echo
    echo "Usage:"
    echo "    ./monitor.sh"
    echo
    echo "Options:"
    echo "    -h    Display this help message"
    echo
    echo "Note:"
    echo "    This script must be run as root."
    echo "    Logs are saved to: $Log_Dir"
}


# Check if the user requested help 
if [ "$1" = "-h" ]
then
    show_help
    exit 0
fi


#----------------------------------

# Verifies all required external commands are installed before running any checks

Error_Handling(){
    local required_cmds=("uptime" "who" "mpstat" "bc" "ps" "free" "df" "iostat" "systemctl" "ip" "ping" "host" "ss" "sar" "journalctl" "dmesg" "getent" "apt")
    local missing_cmds=()

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_cmds+=("$cmd")
        fi
    done

    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        echo "Error: Missing required commands: ${missing_cmds[*]}" >&2
        echo "Please install them before running this script." >&2
        exit 1
    fi
}


#---------------------------------------------


# Checks that the script is being run with root privileges; exits if not 

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root." >&2
        exit 1
    fi
}


#----------------------------------

# Creates the log directory (if missing) and the log file for this run

init_log() {
    if [[ ! -d "$Log_Dir" ]]; then
        mkdir -p "$Log_Dir"
    fi

    touch "$Log_File"
}


#-----------------------------------

# Send all script output (stdout & stderr) to both the screen and the log file

setup_logging() {
   
	exec > >(tee -a "$Log_File") 2>&1
}


#-----------------------------------

# Reports system uptime and last boot time 

report_uptime() {
    echo -e "
====================================
             Uptime
===================================="
    uptime
    
    echo -e "\nLast Boot Time:\n---------------"
    local boot_time
    boot_time=$(who -b)
    
    if [[ -z "$boot_time" ]]; then
        echo "Boot time not available on this system."
    else
        echo "$boot_time"
    fi
}


#--------------------------------------

# Reports current CPU usage % and top CPU-consuming processes

cpu_usage() {
    echo -e "
====================================
             CPU Usage
===================================="
    
    local cpu_used
    cpu_used=$(mpstat 1 1 | awk '/Average/ {print 100 - $NF}')
    
    echo "CPU Usage: ${cpu_used}%"
    
    if (( $(echo "$cpu_used > $THRESHOLD_CPU" | bc -l) )); then
        echo "WARNING: CPU usage is above threshold (${THRESHOLD_CPU}%)!"
    fi
    
    echo -e "\nTop $TOP_N CPU-Consuming Processes:\n-----------------------------------"
    ps -eo user,pid,%cpu,cmd --sort=-%cpu | head -n "$TOP_N"
}


#----------------------------------------

# Reports current memory usage % and top memory-consuming processes

memory_usage() {
    echo -e "
====================================
             Memory Usage
===================================="

    local mem_used
    mem_used=$(free -m | awk '/Mem:/ {printf "%.2f", ($3/$2)*100}')

    echo "Memory Usage: ${mem_used}%"

    if (( $(echo "$mem_used > $THRESHOLD_MEM" | bc -l) )); then
        echo "WARNING: Memory usage is above threshold (${THRESHOLD_MEM}%)!"
    fi

    echo -e "\nTop $TOP_N Memory-Consuming Processes:\n--------------------------------------"
    ps -eo user,pid,%mem,cmd --sort=-%mem | head -n "$TOP_N"
}

#-----------------------------------------


# Reports disk space usage for the root filesystem

disk_usage() {
    echo -e "
====================================
            Disk Usage 
===================================="

    local disk_report
    disk_report=$(df -h /)

    echo "$disk_report"

    local disk_used
    disk_used=$(echo "$disk_report" | awk 'NR==2 {print $5}' | tr -d '%')

    if (( $(echo "$disk_used > $THRESHOLD_DISK" | bc -l) )); then
        echo -e "\nWARNING: Disk usage is above threshold (${THRESHOLD_DISK}%)!"
    fi
}


#-------------------------------------------

# Reports disk I/O activity (read/write rates and utilization) per device

disk_io() {
    echo -e "
====================================
           Disk I/O
===================================="
    
    echo -e "Device\tr/s\tw/s\t%util"
    iostat -dx 1 1 | awk 'NR>3 && NF>0 {print $1"\t"$2"\t"$8"\t"$NF}'
}


#---------------------------------------------

# Checks active/enabled status of key system services

services_check() {
     echo -e "
====================================
         Services Check       
===================================="

    for service in "${SERVICES[@]}"; do
        local active
        active=$(systemctl is-active "$service" 2>/dev/null)
        [[ -z "$active" ]] && active="not-found"

        local enabled
        enabled=$(systemctl is-enabled "$service" 2>/dev/null)
        [[ -z "$enabled" ]] && enabled="not-found"

        echo "$service: Active=[$active], Enabled=[$enabled]"
    done
}


#-----------------------------------------------

# Checks network interfaces, connectivity, DNS, listening ports, and traffic

network_check() {
    echo -e "
====================================
          Network Check
===================================="
    
    echo "Interfaces:"
    ip -br addr
    
    echo -e "\nDefault Gateway:"
    ip route show default
    
    echo -e "\nInternet Connectivity:"
    local ping_result
    ping_result=$(ping -c 2 8.8.8.8 2>&1)
    
    local loss
    loss=$(echo "$ping_result" | grep "packet loss" | awk '{print $6}' | tr -d '%')
    
    if [[ "$loss" -eq 100 ]]; then
        echo "FAILED - No internet connectivity (100% packet loss)"
    elif [[ "$loss" -gt "$THRESHOLD_PACKET_LOSS" ]]; then
        echo "WARNING - Unstable connection ($loss% packet loss)"
    else
        echo "OK - Internet is reachable ($loss% packet loss)"
    fi
    
    echo -e "\nDNS Resolution:"
    if host google.com &> /dev/null; then
        echo "OK - DNS is working"
    else
        echo "FAILED - DNS resolution failed"
    fi
    
    echo -e "\nListening Ports:"
    ss -tulnp | head -n "$TOP_N"
    
    echo -e "\nNetwork Traffic per Interface:"
    sar -n DEV 1 1 | grep -v Average
}


#--------------------------------------------------------

# Scans system logs for boot errors, OOM kills, disk/hardware issues, and failed services

syslogs_check() {
    echo -e "
====================================
           Syslogs Check
===================================="

    echo "Boot & System Errors:"
    local boot_errors
    boot_errors=$(journalctl -b -p err -n 10 --no-pager)

    if [[ -z "$boot_errors" ]]; then
        echo "No boot errors found."
    else
        echo "$boot_errors"
    fi

    echo -e "\nOOM Kills:"
    local oom_kills
    oom_kills=$(dmesg | grep -i "killed process")

    if [[ -z "$oom_kills" ]]; then
        echo "No OOM kills detected."
    else
        echo "$oom_kills"
    fi

    echo -e "\nDisk Warnings:"
    local disk_warnings
    disk_warnings=$(journalctl -p warning --no-pager | grep -i "disk" | tail -5)

    if [[ -z "$disk_warnings" ]]; then
        echo "No disk warnings found."
    else
        echo "$disk_warnings"
    fi

    echo -e "\nHardware & Driver Errors:"
    local HW_errors
    HW_errors=$(dmesg | grep -Ei "error|fail|critical" | tail -5)

    if [[ -z "$HW_errors" ]]; then
        echo "No hardware errors found."
    else
        echo "$HW_errors"
    fi

    echo -e "\nNetworking Issues:"
    local net_issues
    net_issues=$(journalctl -u NetworkManager -p warning -n 5 --no-pager 2>/dev/null)

    if [[ -z "$net_issues" ]]; then
        echo "No networking issues found."
    else
        echo "$net_issues"
    fi

    echo -e "\nFailed Services:"
    local failed_services
    failed_services=$(systemctl --failed --no-pager --plain --no-legend)

    if [[ -z "$failed_services" ]]; then
        echo "No failed services found."
    else
        echo "$failed_services"
    fi
}


#----------------------------------------------------------

# Checks for failed login attempts, sudo group members, and pending security updates

security_check() {
    echo -e "
====================================
          Security Check
===================================="

    echo -e "\nFailed Login Attempts:"
    local failed_logins
    failed_logins=$(journalctl -u ssh -o short-iso 2>/dev/null | grep -E "Failed password|Invalid user" | tail -n 20)

    if [[ -z "$failed_logins" ]]; then
        echo "No failed login attempts found."
    else
        echo "$failed_logins"
    fi

    echo -e "\nUsers with sudo Privileges:"
    local sudo_users
    sudo_users=$(getent group sudo 2>/dev/null || getent group wheel 2>/dev/null)

    if [[ -z "$sudo_users" ]]; then
        echo "Could not determine sudo/wheel group members."
    else
        echo "$sudo_users"
    fi

    echo -e "\nPending Security Updates:"
    local pending_updates
    pending_updates=$(apt list --upgradable 2>/dev/null | tail -n +2)

    if [[ -z "$pending_updates" ]]; then
        echo "No pending updates found."
    else
        echo "$pending_updates" | head -n "$TOP_N"
    fi
}


#-------------------------------------------------------------

# Deletes log files older than the configured retention period

cleanup_old_logs() {
    find "$Log_Dir" -name "health_*.log" -type f -mtime "+${Log_Retention_Days}" -delete
}



#main

Error_Handling
check_root
init_log
setup_logging
report_uptime
cpu_usage
memory_usage
disk_usage
disk_io
services_check
network_check
syslogs_check
security_check
cleanup_old_logs







