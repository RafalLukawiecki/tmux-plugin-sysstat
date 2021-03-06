#!/usr/bin/env bash

set -u
set -e

LC_NUMERIC=C

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

refresh_interval=$(get_tmux_option "status-interval" "5")

# reduce interval by 1 second, so command has time to complete within tmux status refresh interval. Otherwise, tmux will use stale previous command result for 2 times in a row
if [ "$refresh_interval" -gt "1" ]; then
  refresh_interval="$(($refresh_interval - 1))"
fi

cpu_view_tmpl=$(get_tmux_option "@sysstat_cpu_view_tmpl" 'CPU:#[fg=#{cpu.color}]#{cpu.pused}#[default]')

cpu_medium_threshold=$(get_tmux_option "@sysstat_cpu_medium_threshold" "30")
cpu_stress_threshold=$(get_tmux_option "@sysstat_cpu_stress_threshold" "80")

cpu_color_low=$(get_tmux_option "@sysstat_cpu_color_low" "green")
cpu_color_medium=$(get_tmux_option "@sysstat_cpu_color_medium" "yellow")
cpu_color_stress=$(get_tmux_option "@sysstat_cpu_color_stress" "red")

get_cpu_color(){
  local cpu_used=$1

  if fcomp "$cpu_stress_threshold" "$cpu_used"; then
    echo "$cpu_color_stress";
  elif fcomp "$cpu_medium_threshold" "$cpu_used"; then
    echo "$cpu_color_medium";
  else
    echo "$cpu_color_low";
  fi
}

get_cpu_usage() {
  if is_osx; then
    if command_exists "iostat"; then
      iostat -c 2 -w "$refresh_interval" | tail -n 1 | awk '{ print 100-$(NF-3) }'
    else
      top -l 2 -s "$refresh_interval" -n 0 | sed -nr '/CPU usage/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)%[[:space:]]*idle.*/\1/p' | tail -n 1 | awk '{ print 100-$0 }'
    fi
  else
    if command_exists "vmstat"; then
	if is_freebsd; then
	    vmstat -n "$refresh_interval" -c 2 | tail -n 1 | awk '{print 100-$(NF-0)}'
	else
	    vmstat -n "$refresh_interval" 2 | tail -n 1 | awk '{print 100-$(NF-2)}'
	fi
    else
	if is_freebsd; then
	    top -d2 | sed -nr '/CPU:/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)%[[:space:]]*id.*/\1/p' | tail -n 1 | awk '{ print 100-$0 }'
	else
	    top -b -n 2 -d "$refresh_interval" | sed -nr '/%Cpu/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)[[:space:]]*id.*/\1/p' | tail -n 1 | awk '{ print 100-$0 }'
	fi
    fi
  fi
}

print_cpu_usage() {
  local cpu_pused=$(get_cpu_usage)

  local cpu_color=$(get_cpu_color "$cpu_pused")
  
  local cpu_view="$cpu_view_tmpl"
  cpu_view="${cpu_view//'#{cpu.pused}'/$(printf "%.1f%%" "$cpu_pused")}"
  cpu_view="${cpu_view//'#{cpu.color}'/$(echo "$cpu_color" | awk '{ print $1 }')}"
  cpu_view="${cpu_view//'#{cpu.color2}'/$(echo "$cpu_color" | awk '{ print $2 }')}"
  cpu_view="${cpu_view//'#{cpu.color3}'/$(echo "$cpu_color" | awk '{ print $3 }')}"

  echo "$cpu_view"
}

main(){
  print_cpu_usage
}

main
