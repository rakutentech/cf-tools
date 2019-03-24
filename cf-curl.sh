#!/bin/bash

# cf-curl.sh - Same as 'cf curl' but fetches all pages
# Copyright (C) 2016  Rakuten, Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Dependencies: cf, jq >= 1.5

# Run 'cf curl /v2/users' to see what input data looks like

set -euo pipefail
umask 0077

show_usage () {
    cat << EOF
Usage: $(basename "$0") [OPTION]... </v2/...>

  -r                        post-processing: convert array 'resources' to hash
  -k <minutes>              update cache if older than <minutes> (default: 10)
  -n                        ignore cache
  -v                        verbose

Examples:
  $(basename "$0") "/v2/users?results-per-page=10"
  $(basename "$0") "/v2/app_usage_events?results-per-page=10000" > app_usage_events.json
EOF
}

# Process command line options
opt_resources_hash=""
opt_update_cache_minutes=""
opt_verbose=""
while getopts "rk:nvh" opt; do
    case $opt in
        r)  opt_resources_hash="true"
            ;;
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

# Set output mode (raw or converted to hash)
RESOURCES_HASH=${opt_resources_hash:-false}

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

    is_api_v2=false
    is_api_v3=false

    if [[ ${next_url#/v2} != $next_url ]]; then
      is_api_v2=true
    elif [[ ${next_url#/v3} != $next_url ]]; then
      is_api_v3=true
    else
      echo "ERROR: Unable to detect API version for URI '$next_url'" >&2
      exit 1
    fi

    next_url_hash=$(echo "$next_url" "$cf_target" | $(which md5sum || which md5) | cut -d' ' -f1)
    cache_filename="/tmp/.$script_name.$user_id.$next_url_hash.$RESOURCES_HASH"

    if [[ $UPDATE_CACHE_MINUTES != "no_cache" ]]; then
        # Remove expired cache file
        find "$cache_filename" -maxdepth 0 -mmin +$UPDATE_CACHE_MINUTES -exec rm '{}' \; 2>/dev/null || true

        # Read from cache if exists
        if [[ -f "$cache_filename" ]]; then
            cat "$cache_filename"
            return
        fi
    fi

    output_all=()
    json_output=""
    current_page=0
    total_pages=0
    while [[ $next_url != null ]]; do
        # Get data
        json_data=$(cf curl -f "$next_url") || { echo "ERROR: Unable to get data from $next_url" >&2; exit 1; }

        # Show progress
        current_page=$((current_page + 1))
        if [[ $total_pages -eq 0 ]]; then
            if $is_api_v2; then
                total_pages=$(echo "$json_data" | jq '.total_pages')
            elif $is_api_v3; then
                total_pages=$(echo "$json_data" | jq '.pagination.total_pages')
            fi
        fi
        if $VERBOSE; then
            [[ $current_page -gt 1 ]] && echo -ne "\033[1A" >&2
            echo -e "Fetched page $current_page from $total_pages ( $next_url )\033[0K\r" >&2
        fi

        # Generate output
        if $RESOURCES_HASH; then
            if $is_api_v2; then
                output_current=$(echo "$json_data" | jq '[ .resources[] | {key: .metadata.guid, value: .} ] | from_entries')
            elif $is_api_v3; then
                output_current=$(echo "$json_data" | jq '[ .resources[] | {key: .guid, value: .} ] | from_entries')
            fi
        else
            output_current=$(echo "$json_data" | jq '.resources')
        fi

        # Append current output to the result
        output_all+=("$output_current")

        # Get URL for next page of results
        if $is_api_v2; then
            next_url=$(echo "$json_data" | jq .next_url -r)
        elif $is_api_v3; then
            next_url=$(echo "$json_data" | jq .pagination.next.href -r | sed 's#^http\(s\?\)://[^/]\+/v3#/v3#')
        fi
    done

    json_output=$(
        (IFS=$'\n'; echo "${output_all[*]}") | jq -s 'add' |
        if $is_api_v2; then
            jq "{
                  \"total_results\": (. | length),
                  \"total_pages\": 1,
                  \"prev_url\": null,
                  \"next_url\": null,
                  \"resources\": .
                }"
        elif $is_api_v3; then
            jq "{ \"pagination\":
                  {
                    \"total_results\": (. | length),
                    \"total_pages\": 1,
                    \"first\": null,
                    \"last\": null,
                    \"next\": null,
                    \"previous\": null
                  },
                  \"resources\": .
                }"
        fi
    )

    # Update cache file
    if [[ $UPDATE_CACHE_MINUTES != "no_cache" ]]; then
        echo "$json_output" > "$cache_filename"
    fi

    echo "$json_output"
}

get_json "$1"
