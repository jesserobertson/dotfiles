#!/bin/bash
# Custom CPU usage script - shows percentage instead of load average

# Set PATH for tmux environment
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

get_cpu_percent() {
  case $(uname -s) in
    Darwin)
      cpuvalue=$(ps -A -o %cpu | awk -F. '{s+=$1} END {print s}')
      cpucores=$(sysctl -n hw.logicalcpu)
      cpuusage=$(( cpuvalue / cpucores ))
      echo "$cpuusage%"
      ;;
    Linux)
      percent=$(LC_NUMERIC=en_US.UTF-8 top -bn2 -d 0.01 | grep "[C]pu(s)" | tail -1 | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
      echo "$percent"
      ;;
    *)
      echo "N/A"
      ;;
  esac
}

echo "CPU $(get_cpu_percent)"
