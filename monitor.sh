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
SERVICES=("sshd" "cron" "apache2" "ufw" "mariadb" "docker")

THRESHOLD_CPU=80
THRESHOLD_MEM=80
THRESHOLD_DISK=90
THRESHOLD_PACKET_LOSS=20
Log_Retention_Days=7
TOP_N=6

System_Status="HEALTHY"
CURRENT_TIME="$(date +"%B %-d, %Y at %I:%M %p")"


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


#-------------------------------------


# Creates a fresh report.html file with the opening HTML structure

init_report() {
    cat <<- _HTML_HEAD_ > report.html
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>System Health Report</title>

            <style>
                body {
                    background-color: #F5F7FA;
                    font-family: Arial, sans-serif;
                    margin: 0;
                    padding: 30px;
                    color: #2C3E50;
                }

                h1 {
                    color: #2C3E50;
                    text-align: center;
                    margin-bottom: 30px;
                    font-size: 32px;
                }

                .dashboard {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
                    gap: 20px;
                    align-items: start;
                }

                .card {
                    background-color: #FFFFFF;
                    border-radius: 12px;
                    box-shadow: 0 3px 10px rgba(0, 0, 0, 0.08);
                    padding: 20px;
                    box-sizing: border-box;
                    overflow: hidden;
                    border: 1px solid #E8ECF1;
                }

                .card h2 {
                    color: #3498DB;
                    margin-top: 0;
                    margin-bottom: 15px;
                    font-size: 20px;
                    border-bottom: 2px solid #E8ECF1;
                    padding-bottom: 10px;
                }

                .card h3 {
                    color: #2C3E50;
                    font-size: 15px;
                    margin-top: 18px;
                    margin-bottom: 8px;
                }

                .card p {
                    font-size: 32px;
                    font-weight: bold;
                    margin: 10px 0 0;
                    color: #2C3E50;
                }

                pre {
                    background-color: #F8F9FA;
                    padding: 12px;
                    border-radius: 6px;
                    overflow-x: auto;
                    font-size: 13px;
                    line-height: 1.5;
                    white-space: pre-wrap;
                    word-break: break-word;
                }
                
                .overall-card {
                    grid-column: 1 / -1;
                    text-align: center;
                  }
                

                .wide-card {
                    grid-column: span 2;
                }

                .status-ok {
                    color: #27AE60 !important;
                    font-weight: bold;
                }

                .status-warning {
                    color: #F39C12 !important;
                    font-weight: bold;
                }

                .status-failed {
                    color: #E74C3C !important;
                    font-weight: bold;
                }
                
                .status-reasons {
                     margin-top: 10px;
 		     text-align: center;
                    }

		.status-reasons strong {
 		      display: block;
                      font-size: 18px;
                      margin-bottom: 8px;
                     }

                 .status-reasons ul {
                      list-style: none;
                      padding: 0;
                      margin: 0;
                     }

                   .status-reasons li {
                        font-size: 16px;
                        margin: 6px 0;
                       }

                .progress-bar {
 	 	   background-color: #E8ECF1;
 		   border-radius: 8px;
		   height: 14px;
  		   width: 100%;
  		   margin-top: 10px;
	           overflow: hidden;
		  }

		.progress-fill {
 		   height: 100%;
  		   border-radius: 8px;
   		   transition: width 0.3s ease;
		  }

		.fill-ok {
      		   background-color: #27AE60;
		  }

		.fill-warning {
 		    background-color: #F39C12;
		   }

                   .service-row {
  		      display: flex;
   		      align-items: center;
 		      justify-content: space-between;
  		      padding: 8px 0;
                      border-bottom: 1px solid #E8ECF1;
		    }

		   .service-row:last-child {
 			   border-bottom: none;
			 }

		   .service-name {
  			  font-weight: bold;
   			  font-size: 15px;
			 }

		   .badge {
  		      display: inline-block;
  		      padding: 3px 10px;
		      border-radius: 12px;
		      font-size: 12px;
   		      font-weight: bold;
   		      margin-left: 6px;
                     }

		   .badge-ok {
  			  background-color: #D4EFDF;
   			  color: #27AE60;
			 }

		   .badge-warning {
		       background-color: #FDEBD0;
                       color: #F39C12;
		      }

		    .badge-failed {
  		         background-color: #FADBD8;
   			 color: #E74C3C;
			}
                .log-box {
                    border-left: 4px solid;
                    border-radius: 6px;
                    padding: 10px 12px;
                    margin: 10px 0;
                }

                .log-ok {
                    border-left-color: #27AE60;
                    background-color: #EAFAF1;
                }

                .log-issue {
                    border-left-color: #E74C3C;
                    background-color: #FDEDEC;
                }

                .log-warning {
   		    border-left-color: #F39C12;
 		    background-color: #FEF5E7;
                   }

                .log-box pre {
                    background-color: transparent;
                    padding: 0;
                    margin: 4px 0 0;
                }

                .info-box {
                    border-left: 4px solid #BDC3C7;
                    border-radius: 6px;
                    padding: 10px 12px;
                    margin: 10px 0;
                    background-color: #F8F9FA;
                }

                .info-box pre {
                    background-color: transparent;
                    padding: 0;
                    margin: 4px 0 0;
                }


                .report-time {
                    text-align: center;
                    color: #7F8C8D;
                    font-size: 17px;
                    font-weight: bold;
                    margin: -15px 0 30px 0;
                   }

                @media (max-width: 800px) {
                  .wide-card {
                       grid-column: span 1;
                 }

                    body {
                        padding: 15px;
                    }

                    h1 {
                        font-size: 26px;
                    }

                }

            </style>
        </head>

        <body>
            <h1>System Health & Performance Report</h1>
            <p class="report-time">Generated: ${CURRENT_TIME}</p>
           
       <div class="card overall-card">
           <h2>Overall System Status</h2>
           <p id="overall-status" style="font-size:36px;">SYSTEM_STATUS_PLACEHOLDER</p>
	     <div id="status-reasons"></div>
     </div>

            <div class="dashboard">
_HTML_HEAD_
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
    boot_time=$(uptime -s)

    echo "$boot_time"

     cat <<- _HTML_UPTIME_ >> report.html
    <div class="card">
        <h2>Uptime</h2>
        <p>$(uptime -p)</p>
        <strong>Last Boot:</strong>
        <span style="font-size:16px; font-weight:normal;">$(uptime -s)</span>
    </div>
_HTML_UPTIME_

}


#--------------------------------------

# Reports current CPU usage % and top CPU-consuming processes

cpu_usage() {
    echo -e "
====================================
             CPU Usage
===================================="
    
    local cpu_used
    cpu_used=$(mpstat 1 1 | awk '/Average/ {printf "%.2f", 100 - $NF}')
    
    echo "CPU Usage: ${cpu_used}%"
    
    if (( $(echo "$cpu_used > $THRESHOLD_CPU" | bc -l) )); then
        echo "WARNING: CPU usage is above threshold (${THRESHOLD_CPU}%)!"

	 if [[ "$System_Status" == "HEALTHY" ]]; then
              System_Status="WARNING"
	      Status_Reasons+=("CPU usage is above ${THRESHOLD_CPU}%")
         fi
    fi
    
    echo -e "\nTop $TOP_N CPU-Consuming Processes:\n-----------------------------------"
    local top_cpu
    top_cpu=$(ps -eo user,pid,%cpu,cmd --sort=-%cpu | grep -vE 'ps -eo|head -n' | head -n "$TOP_N")

    echo "$top_cpu"

    cat <<- _HTML_CPU_ >> report.html
<div class="card">
    <h2>CPU Usage</h2>
    <p class="$(
        if (( $(echo "$cpu_used > $THRESHOLD_CPU" | bc -l) )); then
            echo "status-warning"
        else
            echo "status-ok"
        fi
    )" style="font-size:32px;">${cpu_used}%</p>
    <div class="progress-bar">
        <div class="progress-fill $(
            if (( $(echo "$cpu_used > $THRESHOLD_CPU" | bc -l) )); then
                echo "fill-warning"
            else
                echo "fill-ok"
            fi
        )" style="width: ${cpu_used}%;"></div>
    </div>
    <strong>Top Processes</strong>
    <pre>${top_cpu}</pre>
</div>
_HTML_CPU_

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

	if [[ "$System_Status" == "HEALTHY" ]]; then
             System_Status="WARNING"
	     Status_Reasons+=("Memory usage is above ${THRESHOLD_MEM}%")
        fi
    fi

    echo -e "\nTop $TOP_N Memory-Consuming Processes:\n--------------------------------------"
   
    local top_memory
    top_memory=$(ps -eo user,pid,%mem,cmd --sort=-%mem | head -n "$TOP_N")

    echo "$top_memory"

        cat <<- _HTML_MEMORY_ >> report.html
    <div class="card">
        <h2>Memory Usage</h2>
        <p class="$(
           if (( $(echo "$mem_used > $THRESHOLD_MEM" | bc -l) )); then
               echo "status-warning"
           else
               echo "status-ok"
           fi
       )" style="font-size:32px;">${mem_used}%</p>
        <div class="progress-bar">
            <div class="progress-fill $(
                if (( $(echo "$mem_used > $THRESHOLD_MEM" | bc -l) )); then
                    echo "fill-warning"
                else
                    echo "fill-ok"
                fi
            )" style="width: ${mem_used}%;"></div>
        </div>
        <strong>Top Processes</strong>
        <pre>${top_memory}</pre>
    </div>
_HTML_MEMORY_

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

	if [[ "$System_Status" == "HEALTHY" ]]; then
             System_Status="WARNING"
             Status_Reasons+=("Disk usage is above ${THRESHOLD_DISK}%")
        fi

    fi

        cat <<- _HTML_DISK_ >> report.html
    <div class="card">
        <h2>Disk Usage</h2>
        <p class="$(
           if (( $(echo "$disk_used > $THRESHOLD_DISK" | bc -l) )); then
                echo "status-warning"
           else
                echo "status-ok"
           fi
       )" style="font-size:32px;">${disk_used}%</p>
        <div class="progress-bar">
            <div class="progress-fill $(
                if (( $(echo "$disk_used > $THRESHOLD_DISK" | bc -l) )); then
                    echo "fill-warning"
                else
                    echo "fill-ok"
                fi
            )" style="width: ${disk_used}%;"></div>
        </div>
        <pre>${disk_report}</pre>
    </div>
_HTML_DISK_

}


#-------------------------------------------

# Reports disk I/O activity (read/write rates and utilization) per device

disk_io() {
    echo -e "
====================================
           Disk I/O
===================================="

    echo -e "Device\tr/s\tw/s\t%util"

    local io_report
    io_report=$(iostat -dx 1 1 | awk '
        $1=="Device" {
            for (i=1; i<=NF; i++) {
                if ($i=="r/s")    r_col=i
                if ($i=="w/s")    w_col=i
                if ($i=="%util")  u_col=i
            }
            found=1
            next
        }
        found && NF>0 {
		printf "%-8s %-8s %-8s %-8s\n", $1, $r_col, $w_col, $u_col
        }
    ')

    echo "$io_report"

    cat <<- _HTML_DISK_IO_ >> report.html
        <div class="card">
            <h2>Disk I/O</h2>
            <pre>Device   r/s      w/s      %util
${io_report}</pre>
        </div>
_HTML_DISK_IO_

}

#---------------------------------------------

# Checks active/enabled status of key system services and reports
# each one as a colored row with Active/Enabled badges

services_check() {
     echo -e "
====================================
         Services Check
===================================="

    local services_html=""

    for service in "${SERVICES[@]}"; do
        local active
        active=$(systemctl is-active "$service" 2>/dev/null)
        [[ -z "$active" ]] && active="not-found"

        local enabled
        enabled=$(systemctl is-enabled "$service" 2>/dev/null)
        [[ -z "$enabled" ]] && enabled="not-found"

        echo "$service: Active=[$active], Enabled=[$enabled]"

        # Determine badge color for the Active state
       
       	local active_class
        case "$active" in
            active)    active_class="badge-ok" ;;
            inactive)  active_class="badge-warning" ;;
            *)         active_class="badge-failed" ;;
        esac

        # Determine badge color for the Enabled state
        # "alias" means this unit name is a symlink to another unit
        # (e.g. sshd -> ssh on Ubuntu), so it's treated as OK, not a failure
       
       	local enabled_class
        case "$enabled" in
            enabled)   enabled_class="badge-ok" ;;
            alias)     enabled_class="badge-ok" ;;
            disabled)  enabled_class="badge-warning" ;;
            *)         enabled_class="badge-failed" ;;
        esac

        # If the service isn't active, downgrade overall system status
        if [[ "$active" == "inactive" ]]; then
            if [[ "$System_Status" == "HEALTHY" ]]; then
                 System_Status="WARNING"
            fi

	    Status_Reasons+=("$service service is inactive")
        fi

        services_html="${services_html}<div class=\"service-row\"><span class=\"service-name\">${service}</span><span><span class=\"badge ${active_class}\">${active^^}</span><span class=\"badge ${enabled_class}\">${enabled^^}</span></span></div>"
    done

    echo "<div class=\"card\"><h2>Services</h2>${services_html}</div>" >> report.html

}


#-----------------------------------------------

# Checks network interfaces, connectivity, DNS, listening ports, and traffic.
# Connectivity/DNS use a colored log-box (ok/issue); the rest use a
# neutral info-box since they're informational, not pass/fail.

network_check() {
    echo -e "
====================================
          Network Check
===================================="

    # Network Interfaces
    local interfaces
    interfaces=$(ip -br addr)

    echo "Interfaces:"
    echo "$interfaces"

    # Default Gateway
    local gateway
    gateway=$(ip route show default)

    echo -e "\nDefault Gateway:"
    echo "$gateway"

    # Internet Connectivity
    echo -e "\nInternet Connectivity:"

    local ping_status
    ping -c 2 8.8.8.8 &> /dev/null
    ping_status=$?

    local ping_result
    local loss
    local net_status

    if [[ $ping_status -ne 0 ]]; then
        net_status="FAILED - No internet connectivity (host unreachable)"
    else
        ping_result=$(ping -c 2 8.8.8.8 2>&1)
        loss=$(echo "$ping_result" | grep "packet loss" | awk '{print $6}' | tr -d '%')

        if [[ -z "$loss" ]]; then
             net_status="WARNING - Could not determine packet loss"
	elif [[ "$loss" -eq 100 ]]; then
            net_status="FAILED - No internet connectivity (100% packet loss)"
        elif [[ "$loss" -gt "$THRESHOLD_PACKET_LOSS" ]]; then
            net_status="WARNING - Unstable connection ($loss% packet loss)"
        else
            net_status="OK - Internet is reachable ($loss% packet loss)"
        fi
    fi


    if [[ "$net_status" == FAILED* ]]; then
         System_Status="CRITICAL"
	 Status_Reasons+=("Network connectivity failed")
    elif [[ "$net_status" == WARNING* && "$System_Status" != "CRITICAL" ]]; then
           System_Status="WARNING"
	   Status_Reasons+=("Network connectivity has a warning")
    fi

    echo "$net_status"

    # DNS Resolution
    local dns_status

    echo -e "\nDNS Resolution:"

    if host google.com &> /dev/null; then
        dns_status="OK - DNS is working"
    else
        dns_status="FAILED - DNS resolution failed"
    fi


    if [[ "$dns_status" == FAILED* ]]; then
         System_Status="CRITICAL"
	 Status_Reasons+=("DNS resolution failed")
    fi

    echo "$dns_status"

    # Listening Ports
    local listening_ports
    listening_ports=$(ss -tulnp | head -n "$TOP_N")

    echo -e "\nListening Ports:"
    echo "$listening_ports"

    # Network Traffic
    local network_traffic
    network_traffic=$(sar -n DEV 1 1 | grep -v Average)

    echo -e "\nNetwork Traffic per Interface:"
    echo "$network_traffic"

    local network_traffic_html
    network_traffic_html=$(echo "$network_traffic" | awk '
    /IFACE/ {print; next}
    /^[0-9]/ && $2 != "IFACE" {print}
')

    # Determine log-box status class for Connectivity and DNS
    local net_status_class
    case "$net_status" in
        OK*)     net_status_class="log-ok" ;;
        *)       net_status_class="log-issue" ;;
    esac

    local dns_status_class
    case "$dns_status" in
        OK*)     dns_status_class="log-ok" ;;
        *)       dns_status_class="log-issue" ;;
    esac

    # HTML Report
    cat <<- _HTML_NETWORK_ >> report.html
        <div class="card wide-card">
            <h2>Network</h2>

            <h3>Internet Connectivity</h3>
            <div class="log-box ${net_status_class}">
                <pre>${net_status}</pre>
            </div>

            <h3>DNS Resolution</h3>
            <div class="log-box ${dns_status_class}">
                <pre>${dns_status}</pre>
            </div>

            <h3>Interfaces</h3>
            <div class="info-box">
                <pre>${interfaces}</pre>
            </div>

            <h3>Default Gateway</h3>
            <div class="info-box">
                <pre>${gateway}</pre>
            </div>

            <h3>Listening Ports</h3>
            <div class="info-box">
                <pre>${listening_ports}</pre>
            </div>

            <h3>Network Traffic per Interface</h3>
            <div class="info-box">
                <pre>${network_traffic_html}</pre>
            </div>
        </div>
_HTML_NETWORK_

}


#--------------------------------------------------------
# Scans system logs for boot errors, WSL errors, OOM kills,
# disk warnings, hardware/driver errors, networking issues,
# and failed services. Each result section is wrapped in a
# colored log-box (green = ok, red = issue found).

syslogs_check() {
    echo -e "
====================================
           Syslogs Check
===================================="


    # Boot & System Errors
    echo "Boot & System Errors:"
    local boot_errors
    boot_errors=$(journalctl -b -p err --no-pager \
        | grep -vE "WSL|dxg|PCI|ubuntu-insights|Failed to start")

    if [[ -z "$boot_errors" ]]; then
        boot_errors="No boot errors found."
    fi

    echo "$boot_errors"


    # WSL / System Errors
    echo -e "\nWSL / System Errors:"
    local wsl_errors
    wsl_errors=$(journalctl -b -p err --no-pager \
        | grep "WSL" | tail -n 10)

    if [[ -z "$wsl_errors" ]]; then
        wsl_errors="No WSL errors found."
    fi

    echo "$wsl_errors"


    # OOM Kills
    echo -e "\nOOM Kills:"
    local oom_kills
    oom_kills=$(dmesg 2>/dev/null | grep -i "killed process")

    if [[ -z "$oom_kills" ]]; then
        oom_kills="No OOM kills detected."
    fi

    echo "$oom_kills"


    # Disk Warnings
    echo -e "\nDisk Warnings:"
    local disk_warnings
    disk_warnings=$(journalctl -p warning --no-pager \
        | grep -i "disk" | tail -n 5)

    if [[ -z "$disk_warnings" ]]; then
        disk_warnings="No disk warnings found."
    fi

    echo "$disk_warnings"


    # Hardware & Driver Errors
    echo -e "\nHardware & Driver Errors:"
    local HW_errors
    HW_errors=$(journalctl -b -p err --no-pager \
        | grep -Ei "hardware|driver|firmware|gpu|pci|usb" \
        | grep -vE "dxg|WSL" \
        | tail -n 5)

    if [[ -z "$HW_errors" ]]; then
        HW_errors="No hardware or driver errors found."
    fi

    echo "$HW_errors"


    # Networking Issues
    echo -e "\nNetworking Issues:"
    local net_issues
    net_issues=$(journalctl -u NetworkManager -p warning -n 5 --no-pager 2>/dev/null)

    if [[ -z "$net_issues" || "$net_issues" == "-- No entries --" ]]; then
        net_issues="No networking issues found."
    fi

    echo "$net_issues"


    # Current Failed Services
    echo -e "\nFailed Services:"
    local failed_services
    failed_services=$(systemctl --failed --no-pager --plain --no-legend)

    if [[ -z "$failed_services" ]]; then
        failed_services="No failed services found."
    fi

    echo "$failed_services"


    # Service Start Failures in Logs
    echo -e "\nService Start Failures in Logs:"
    local service_failures
    service_failures=$(journalctl -b --no-pager \
        | grep -Ei "Failed to start|Failed at step" \
        | tail -n 10)

    if [[ -z "$service_failures" ]]; then
        service_failures="No service start failures found."
    fi

    echo "$service_failures"


    # Determine log-box status class for each section
    # (log-ok = default "No X found" message, log-issue = real entries found)
    local boot_errors_class="log-ok"
    [[ "$boot_errors" != "No boot errors found." ]] && boot_errors_class="log-issue"

    local wsl_errors_class="log-ok"
    [[ "$wsl_errors" != "No WSL errors found." ]] && wsl_errors_class="log-issue"

    local oom_kills_class="log-ok"
    [[ "$oom_kills" != "No OOM kills detected." ]] && oom_kills_class="log-issue"

    local disk_warnings_class="log-ok"
    [[ "$disk_warnings" != "No disk warnings found." ]] && disk_warnings_class="log-issue"

    local HW_errors_class="log-ok"
    [[ "$HW_errors" != "No hardware or driver errors found." ]] && HW_errors_class="log-issue"

    local net_issues_class="log-ok"
    [[ "$net_issues" != "No networking issues found." ]] && net_issues_class="log-issue"

    local failed_services_class="log-ok"
    [[ "$failed_services" != "No failed services found." ]] && failed_services_class="log-issue"

    local service_failures_class="log-ok"
    [[ "$service_failures" != "No service start failures found." ]] && service_failures_class="log-issue"


    # HTML Report
    cat <<- _HTML_SYSLOGS_ >> report.html
        <div class="card wide-card">
            <h2>System Logs</h2>

            <h3>Boot & System Errors</h3>
            <div class="log-box ${boot_errors_class}">
                <pre>${boot_errors}</pre>
            </div>

            <h3>WSL / System Errors</h3>
            <div class="log-box ${wsl_errors_class}">
                <pre>${wsl_errors}</pre>
            </div>

            <h3>OOM Kills</h3>
            <div class="log-box ${oom_kills_class}">
                <pre>${oom_kills}</pre>
            </div>

            <h3>Disk Warnings</h3>
            <div class="log-box ${disk_warnings_class}">
                <pre>${disk_warnings}</pre>
            </div>

            <h3>Hardware & Driver Errors</h3>
            <div class="log-box ${HW_errors_class}">
                <pre>${HW_errors}</pre>
            </div>

            <h3>Networking Issues</h3>
            <div class="log-box ${net_issues_class}">
                <pre>${net_issues}</pre>
            </div>

            <h3>Current Failed Services</h3>
            <div class="log-box ${failed_services_class}">
                <pre>${failed_services}</pre>
            </div>

            <h3>Service Start Failures in Logs</h3>
            <div class="log-box ${service_failures_class}">
                <pre>${service_failures}</pre>
            </div>
        </div>
_HTML_SYSLOGS_

}


#----------------------------------------------------------

# Checks for failed login attempts, sudo group members, and pending security updates

security_check() {
    echo -e "
====================================
          Security Check
===================================="

    # Detect whether the SSH service is named "ssh" or "sshd" on this system
    local ssh_service
    if systemctl list-unit-files | grep -q "^ssh\.service"; then
        ssh_service="ssh"
    elif systemctl list-unit-files | grep -q "^sshd\.service"; then
        ssh_service="sshd"
    else
        ssh_service=""
    fi

    echo -e "\nFailed Login Attempts:"
    local failed_logins
    if [[ -n "$ssh_service" ]]; then
        failed_logins=$(journalctl -u "$ssh_service" -o short-iso 2>/dev/null | grep -E "Failed password|Invalid user" | tail -n 20)
    else
        failed_logins=""
    fi
    
    if [[ -n "$failed_logins" ]]; then
         if [[ "$System_Status" == "HEALTHY" ]]; then
              System_Status="WARNING"
         fi
              Status_Reasons+=("Failed login attempts detected")
         fi

    if [[ -z "$ssh_service" ]]; then
        echo "SSH service not found on this system (checked 'ssh' and 'sshd')."
    elif [[ -z "$failed_logins" ]]; then
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

    local pending_updates
    pending_updates=$(apt list --upgradable 2>/dev/null | tail -n +2)

    local security_updates
    security_updates=$(echo "$pending_updates" | grep -F "resolute-security")

    local regular_updates
    regular_updates=$(echo "$pending_updates" | grep -v -F "resolute-security")

    if [[ -n "$security_updates" ]]; then
       if [[ "$System_Status" == "HEALTHY" ]]; then
            System_Status="WARNING"
       fi
            Status_Reasons+=("Pending security updates found")
       fi 
   
    local security_updates_display
    local regular_updates_display

    security_updates_display=$(echo "$security_updates" | head -n "$TOP_N")
    regular_updates_display=$(echo "$regular_updates" | head -n "$TOP_N")

    echo -e "\nPending Security Updates:"
    if [[ -z "$security_updates" ]]; then
         echo "No pending security updates found."
    else
         echo "$security_updates_display"
    fi

    echo -e "\nOther Pending Updates:"
    if [[ -z "$regular_updates" ]]; then
         echo "No other pending updates found."
    else
         echo "$regular_updates_display"
    fi

   
    local login_status_class
    if [[ -z "$failed_logins" ]]; then
        login_status_class="log-ok"
    else
        login_status_class="log-issue"
    fi

    local updates_status_class
    if [[ -z "$security_updates" ]]; then
         updates_status_class="log-ok"
    else
         updates_status_class="log-warning"
    fi

cat <<- _HTML_SECURITY_ >> report.html
    <div class="card wide-card">
        <h2>Security</h2>

        <h3>Failed Login Attempts</h3>
        <div class="log-box ${login_status_class}">
            <pre>${failed_logins:-No failed login attempts found.}</pre>
        </div>

        <h3>Users with sudo Privileges</h3>
        <div class="info-box">
            <pre>${sudo_users:-Could not determine sudo/wheel group members.}</pre>
        </div>

        <h3>Pending Security Updates</h3>
        <div class="log-box ${updates_status_class}">
            <pre>${security_updates_display:-No pending security updates found.}</pre>
        </div>

        <h3>Other Pending Updates</h3>
        <div class="info-box">
            <pre>${regular_updates_display:-No other pending updates found.}</pre>
        </div>
    </div>
_HTML_SECURITY_

}


#-------------------------------------------------------------

# Deletes log files older than the configured retention period

cleanup_old_logs() {
    find "$Log_Dir" -name "health_*.log" -type f -mtime "+${Log_Retention_Days}" -delete
}


#--------------------------------------------------------------


close_report() {
    local status_class

    case "$System_Status" in
        HEALTHY)
            status_class="status-ok"
            ;;
        WARNING)
            status_class="status-warning"
            ;;
        CRITICAL)
            status_class="status-failed"
            ;;
    esac

    sed -i "s/SYSTEM_STATUS_PLACEHOLDER/${System_Status}/" report.html
    sed -i "s/id=\"overall-status\"/id=\"overall-status\" class=\"${status_class}\"/" report.html

    # Add status reasons only for WARNING or CRITICAL

    if [[ "$System_Status" == "WARNING" || "$System_Status" == "CRITICAL" ]] && [[ ${#Status_Reasons[@]} -gt 0 ]]; then
         local reasons_html=""

         reasons_html='<div class="status-reasons">'
         reasons_html+='<strong>Reason:</strong>'
         reasons_html+='<ul>'

        for reason in "${Status_Reasons[@]}"; do
           reasons_html+="<li>${reason}</li>"
        done

        reasons_html+='</ul>'
        reasons_html+='</div>'

        sed -i "s|<div id=\"status-reasons\"></div>|${reasons_html}|" report.html
    fi
   

    echo "</div>" >> report.html
    echo "</body>" >> report.html
    echo "</html>" >> report.html
}



#main

Error_Handling
check_root
init_log
setup_logging
init_report
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
close_report
/mnt/c/Windows/explorer.exe "$(wslpath -w "$(pwd)/report.html")" 








