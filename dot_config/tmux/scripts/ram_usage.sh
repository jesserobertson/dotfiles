#!/bin/bash
# Custom RAM usage script - consistent formatting

# Set PATH for tmux environment
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

get_ram_usage() {
  case $(uname -s) in
    Darwin)
      # Get used memory in MiB
      used_mem=$(vm_stat | grep ' active\|wired\|compressor\|speculative' | sed 's/[^0-9]//g' | paste -sd ' ' - | awk -v pagesize=$(pagesize) '{printf "%d\n", ($1+$2+$3+$5) * pagesize / 1048576}')
      # Get total memory in GB
      total_mem=$(sysctl -n hw.memsize | awk '{print int($0/1024/1024/1024)}')

      if ((used_mem < 1024)); then
        echo "${used_mem}MB/${total_mem}GB"
      else
        memory=$((used_mem/1024))
        echo "${memory}GB/${total_mem}GB"
      fi
      ;;
    Linux)
      usage="$(free -h | awk 'NR==2 {print $3}')"
      total="$(free -h | awk 'NR==2 {print $2}')"
      formated="${usage}/${total}"
      echo "${formated//i/B}"
      ;;
    *)
      echo "N/A"
      ;;
  esac
}

echo "RAM $(get_ram_usage)"
