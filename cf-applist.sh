#!/bin/bash

# cf-applist.sh - Show list of Applications running on Cloud Foundry
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

# Dependencies: cf >= v6.43, jq >= 1.5

# Run 'cf curl /v2/apps' to see what input data looks like

set -euo pipefail
umask 0077

PROPERTIES_TO_SHOW_H=("#" Name GUID State Memory Instances Disk_quota SSH Docker Diego Stack IS Organization Organization_IS Space Space_IS Created Updated App_URL Routes_URL Buildpack Detected_Buildpack)
PROPERTIES_TO_SHOW=(.entity.name .metadata.guid .entity.state .entity.memory .entity.instances .entity.disk_quota .entity.enable_ssh .entity.docker_image .entity.diego .extra.stack .extra.isolation_segment .extra.organization .extra.organization_isolation_segment .extra.space .extra.space_isolation_segment .metadata.created_at .metadata.updated_at .metadata.url .entity.routes_url .entity.buildpack .entity.detected_buildpack)

show_usage () {
    cat << EOF
Usage: $(basename "$0") [OPTION]...

  -s <sort field>           sort by specified field index or its name
  -S <sort field>           sort by specified field index or its name (numeric)
  -f <field1,field2,...>    show only fields specified by indexes or field names 
  -o <organization name>    specify target organization 
  -x <space name>           specify target space
  -c <minutes>              filter objects created within last <minutes>
  -u <minutes>              filter objects updated within last <minutes>
  -C <minutes>              filter objects created more than <minutes> ago
  -U <minutes>              filter objects updated more than <minutes> ago
  -k <minutes>              update cache if older than <minutes> (default: 10)
  -n                        ignore cache
  -N                        do not format output and keep it tab-separated (useful for further processing)
  -j                        print json (filter and sort options are not applied when -j is in use)
  -v                        verbose 
  -h                        display this help and exit
EOF
}

P_TO_SHOW_H=$(echo "${PROPERTIES_TO_SHOW_H[*]}")
P_TO_SHOW=$(IFS=','; echo "${PROPERTIES_TO_SHOW[*]}")

p_index() {
    for i in "${!PROPERTIES_TO_SHOW_H[@]}"; do
       if [[ "${PROPERTIES_TO_SHOW_H[$i]}" == "$1" ]]; then
           echo $(($i+1))
       fi
    done
}

p_names_to_indexes() {
    IFS=','
    fields=()
    for f in $1; do
        if [[ $f =~ ^[0-9]+$ ]]; then
            fields+=($f)
        else
            fields+=($(p_index "$f"))
        fi
    done
    echo "${fields[*]}"
}

# Process command line options
opt_sort_options=""
opt_sort_field=""
opt_created_minutes=""
opt_updated_minutes=""
opt_created_minutes_older_than=""
opt_updated_minutes_older_than=""
opt_cut_fields=""
opt_format_output=""
opt_update_cache_minutes=""
opt_print_json=""
opt_verbose=""
opt_org=""
opt_space=""

while getopts "s:S:c:u:C:U:f:k:o:x:nNjvh" opt; do
    case $opt in
        s)  opt_sort_options="-k"
            opt_sort_field=$OPTARG
            ;;
        S)  opt_sort_options="-nk"
            opt_sort_field=$OPTARG
            ;;
        c)  opt_created_minutes=$OPTARG
            ;;
        u)  opt_updated_minutes=$OPTARG
            ;;
        C)  opt_created_minutes_older_than=$OPTARG
            ;;
        U)  opt_updated_minutes_older_than=$OPTARG
            ;;
        f)  opt_cut_fields=$OPTARG
            ;;
        k)  opt_update_cache_minutes=$OPTARG
            ;;
        N)  opt_format_output="false"
            ;;
        n)  opt_update_cache_minutes="no_cache"
            ;;
        j)  opt_print_json="true"
            ;;
        v)  opt_verbose="true"
            ;;
        o)  opt_org=$OPTARG
            ;;
        x)  opt_space=$OPTARG
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

# Set verbosity
VERBOSE=${opt_verbose:-false}

# Set printing json option (default: false)
PRINT_JSON=${opt_print_json:-false}

# Set sorting options, default is '-k1' (See 'man sort')
if [[ -n $opt_sort_field ]]; then
    opt_sort_field=$(( $(p_names_to_indexes "$opt_sort_field") - 1 ))
fi
SORT_OPTIONS="${opt_sort_options:--k} ${opt_sort_field:-1},${opt_sort_field:-1}"

# Set cache update option (default: 10)
UPDATE_CACHE_MINUTES=${opt_update_cache_minutes:-10}

# Define command to cut specific fields
if [[ -z $opt_cut_fields ]]; then
    CUT_FIELDS="cat"
else
    opt_cut_fields=$(p_names_to_indexes "$opt_cut_fields")
    cut_fields_awk=$(echo "$opt_cut_fields" | sed 's/\([0-9][0-9]*\)/$\1/g; s/,/"\\t"/g')
    CUT_FIELDS='awk -F"\t" "{print $cut_fields_awk}"'
fi

# Define format output command
if [[ $opt_format_output == "false" ]]; then
    FORMAT_OUTPUT="cat"
else
    FORMAT_OUTPUT="column -ts $'\t'"
fi

# Post filter
POST_FILTER=""
if [[ -n $opt_created_minutes ]]; then
    POST_FILTER="$POST_FILTER . |
                 (.metadata.created_at | (now - fromdate) / 60) as \$created_min_ago |
                 select (\$created_min_ago < $opt_created_minutes) |"
fi
if [[ -n $opt_updated_minutes ]]; then
    POST_FILTER="$POST_FILTER . |
                 (.metadata.updated_at as \$updated_at | if \$updated_at != null then \$updated_at | (now - fromdate) / 60 else null end ) as \$updated_min_ago |
                 select (\$updated_min_ago != null) | select (\$updated_min_ago < $opt_updated_minutes) |"
fi
if [[ -n $opt_created_minutes_older_than ]]; then
    POST_FILTER="$POST_FILTER . |
                 (.metadata.created_at | (now - fromdate) / 60) as \$created_min_ago |
                 select (\$created_min_ago > $opt_created_minutes_older_than) |"
fi
if [[ -n $opt_updated_minutes_older_than ]]; then
    POST_FILTER="$POST_FILTER . |
                 (.metadata.updated_at as \$updated_at | if \$updated_at != null then \$updated_at | (now - fromdate) / 60 else null end ) as \$updated_min_ago |
                 select (\$updated_min_ago != null) | select (\$updated_min_ago > $opt_updated_minutes_older_than) |"
fi

# Organization filter
# If organization is not found, command exits with error-code 1
ORG_FILTER=""
if [[ ! -z $opt_org ]]; then
    ORG_FILTER="&q=organization_guid:`cf org $opt_org --guid`"
fi

# Space filter
# If space is not found, command exits with error-code 1
SPACE_FILTER=""
if [[ ! -z $opt_space ]]; then
    SPACE_FILTER="&q=space_guid:`cf space $opt_space --guid`"
fi

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
        if $is_api_v2; then
            output_current=$(echo "$json_data" | jq '[ .resources[] | {key: .metadata.guid, value: .} ] | from_entries')
        elif $is_api_v3; then
            output_current=$(echo "$json_data" | jq '[ .resources[] | {key: .guid, value: .} ] | from_entries')
        fi


        # Append current output to the result
        output_all+=("$output_current")

        # Get URL for next page of results
        if $is_api_v2; then
            next_url=$(echo "$json_data" | jq .next_url -r)
        elif $is_api_v3; then
            next_url=$(echo "$json_data" | jq .pagination.next.href -r | sed -E 's#^http(s?)://[^/]+/v3#/v3#')
        fi
    done
    json_output=$( (IFS=$'\n'; echo "${output_all[*]}") | jq -s 'add' )

    # Update cache file
    if [[ $UPDATE_CACHE_MINUTES != "no_cache" ]]; then
        echo "$json_output" > "$cache_filename"
    fi

    echo "$json_output"
}

# Get organizations
next_url="/v2/organizations?results-per-page=100"
json_organizations=$(get_json "$next_url" | jq "{organizations:.}")

# Get spaces
next_url="/v2/spaces?results-per-page=100"
json_spaces=$(get_json "$next_url" | jq "{spaces:.}")

# Get stacks
next_url="/v2/stacks?results-per-page=100"
json_stacks=$(get_json "$next_url" | jq "{stacks:.}")

# Get isolation_segments
next_url="/v3/isolation_segments?per_page=100"
json_isolation_segments=$(get_json "$next_url" | jq "{isolation_segments:.}")

### Custom part
# Set organization and space
org_guid="8a646d58-f913-4344-8006-8a436413beb4"
space_guid="0728c36a-5907-40d3-966a-88f5787530c3"

# Get applications
next_url="/v2/apps?results-per-page=100${ORG_FILTER}${SPACE_FILTER}"
json_apps=$(get_json "$next_url" | jq "{apps:.}")

# Add extra data to json_organizations
json_organizations=$(echo "$json_organizations"$'\n'"$json_isolation_segments" | \
     jq -s 'add' | \
     jq '.isolation_segments as $isolation_segments |
         .organizations[] |= (.extra.isolation_segment = ( $isolation_segments[.entity.default_isolation_segment_guid // empty].name // null )
                             ) |
         .organizations | {organizations:.}')

# Add extra data to json_spaces
json_spaces=$(echo "$json_organizations"$'\n'"$json_spaces"$'\n'"$json_isolation_segments" | \
     jq -s 'add' | \
     jq '.organizations as $organizations |
         .isolation_segments as $isolation_segments |
         .spaces[] |= (.extra.organization = $organizations[.entity.organization_guid].entity.name |
                       .extra.isolation_segment = ( $isolation_segments[.entity.isolation_segment_guid // empty].name // null )
                      ) |
         .spaces | {spaces:.}')

# Add extra data to json_apps
json_apps=$(echo "$json_stacks"$'\n'"$json_spaces"$'\n'"$json_isolation_segments"$'\n'"$json_organizations"$'\n'"$json_apps" | \
     jq -s 'add' | \
     jq '.stacks as $stacks |
         .spaces as $spaces |
         .isolation_segments as $isolation_segments |
         .organizations as $organizations |
         .apps[] |= (.extra.stack = $stacks[.entity.stack_guid].entity.name |
                     .extra.organization = $spaces[.entity.space_guid].extra.organization |
                     .extra.space = $spaces[.entity.space_guid].entity.name |
                     .extra.organization_isolation_segment = $organizations[$spaces[.entity.space_guid].entity.organization_guid].extra.isolation_segment |
                     .extra.space_isolation_segment = $spaces[.entity.space_guid].extra.isolation_segment |
                     .extra.isolation_segment = (.extra.space_isolation_segment // .extra.organization_isolation_segment)
                    ) |
         .apps | {apps:.}')

if $PRINT_JSON; then
    echo "$json_apps"
else
    # Generate application list (tab-delimited)
    app_list=$(echo "$json_apps" |\
        jq -r ".apps[] |
            $POST_FILTER
            [ $P_TO_SHOW | select (. == null) = \"<null>\" | select (. == \"\") = \"<empty>\" ] |
            @tsv")

    # Print headers and app_list
    (echo $P_TO_SHOW_H | tr ' ' '\t'; echo -n "$app_list" | sort -t $'\t' $SORT_OPTIONS | nl -w4) | \
        # Cut fields
        eval $CUT_FIELDS | \
        # Format columns for nice output
        eval $FORMAT_OUTPUT | less --quit-if-one-screen --no-init --chop-long-lines
fi
