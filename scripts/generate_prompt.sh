#!/usr/bin/env bash

set -uo pipefail

get_prompt() {    
    local reachability=$(cat /tmp/server_stats/reachability)
    IFS=':' read -r num_up total <<< "$reachability"
    echo "$num_up/$total↑ \$ "
}

export PS1='$(get_prompt)'
