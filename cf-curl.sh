#!/bin/bash

# Same as 'cf curl' but fetches all pages

# Stanislav German-Evtushenko, 2016
# Rakuten inc.

# Dependencies: cf, jq >= 1.5

# Try 'cf curl /v2/users' to see what input data looks like

set -euo pipefail
umask 0077

show_usage () {
    cat << EOF
Usage: $(basename "$0") [OPTION]... </v2/...>

  -k <minutes>              update cache if older than <minutes> (default: 10)
  -n                        ignore cache
  -v                        verbose

Example:
  $(basename "$0") "/v2/users?results-per-page=10"
EOF
}

# Process command line options
opt_update_cache_minutes=""
opt_verbose=""
while getopts "k:nvh" opt; do
    case $opt in
        k)  opt_update_cache_minutes=$OPTARG
            ;;
        n)  opt_update_cache_minutes="no_cache"
            ;;
        v)  opt_verbose="true"
            ;;
        h)
            show_usage
            exit 0
            ;;
        ?)
            show_usage >&2
            exit 1
            ;;
    esac
done
shift $(($OPTIND - 1))

# Set URL
if [[ $# -ne 1 ]]; then
    show_usage >&2
    exit 1
fi
URL="$1"

# Set verbosity
VERBOSE=${opt_verbose:-false}

# Set cache update option (default: 10)
UPDATE_CACHE_MINUTES=${opt_update_cache_minutes:-10}

# The following variables are used to generate cache file path
script_name=$(basename "$0")
user_id=$(id -u)
cf_target=$(cf target)

get_json () {
    next_url="$1"

    next_url_hash=$(echo "$next_url" "$cf_target" | $(which md5sum || which md5) | cut -d' ' -f1)
    cache_filename="/tmp/.$script_name.$user_id.$next_url_hash"

    if [[ $UPDATE_CACHE_MINUTES != "no_cache" ]]; then
        # Remove expired cache file
        find "$cache_filename" -maxdepth 0 -mmin +$UPDATE_CACHE_MINUTES -exec rm '{}' \; 2>/dev/null || true

        # Read from cache if exists
        if [[ -f "$cache_filename" ]]; then
            cat "$cache_filename"
            return
        fi
    fi

    json_output=""
    current_page=0
    total_pages=0
    while [[ $next_url != null ]]; do
        # Get data
        json_data=$(cf curl "$next_url")

        # Show progress
        current_page=$((current_page + 1))
        if [[ $total_pages -eq 0 ]]; then
            total_pages=$(cf curl "$next_url" | jq '.total_pages')
        fi
        if $VERBOSE; then
            echo -ne "Fetched page $current_page from $total_pages ( $next_url )\e[0K\r" >&2
        fi

        # Generate output
        output=$(echo "$json_data" | jq '[ .resources[] | {key: .metadata.guid, value: .} ] | from_entries')

        # Add output to json_output
        json_output=$(echo "${json_output}"$'\n'"$output" | jq -s 'add')

        # Get URL for next page of results
        next_url=$(echo "$json_data" | jq .next_url -r)
    done
    echo "$json_output"

    # Update cache file
    if [[ $UPDATE_CACHE_MINUTES != "no_cache" ]]; then
        echo "$json_output" > "$cache_filename"
    fi
}

get_json "$1"
