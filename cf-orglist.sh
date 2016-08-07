#!/bin/bash

# Show list of Organizations created on Cloud Foundry

# Stanislav German-Evtushenko, 2016
# Rakuten inc.

# Dependencies: cf, jq >= 1.5

# Try 'cf curl /v2/apps' to see what input data looks like

set -euo pipefail

PROPERTIES_TO_SHOW_H=("#" Name Status Managers Users Auditors Created Updated Organization_URL)
PROPERTIES_TO_SHOW=(.entity.name .entity.status .entity.managers_url .entity.users_url .entity.auditors_url .metadata.created_at .metadata.updated_at .metadata.url)

show_usage () {
    cat << EOF
Usage: $(basename "$0") [OPTION]...

  -s <sort field>           sort by specified field index or its name
  -S <sort field>           sort by specified field index or its name (numeric)
  -f <field1,field2,...>    show only fields specified by indexes or field names
  -c <minutes>              filter objects created within last <minutes>
  -u <minutes>              filter objects updated within last <minutes>
  -C <minutes>              filter objects created more than <minutes> ago
  -U <minutes>              filter objects updated more than <minutes> ago
  -k <minutes>              update cache if older than <minutes> (default: 10)
  -n                        ignore cache
  -N                        do not format output and keep it tab-separated (useful for further processing)
  -j                        print json (filter and sort options are not applied when -j is in use)
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
while getopts "s:S:c:u:C:U:f:k:nNjh" opt; do
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

# Set printing json option (default: false)
PRINT_JSON=${opt_print_json:-false}

# Set sorting options, default is '-k1' (See 'man sort')
if [[ -n $opt_sort_field ]]; then
    opt_sort_field=$(( $(p_names_to_indexes "$opt_sort_field") - 1 ))
fi
SORT_OPTIONS="${opt_sort_options:--k} ${opt_sort_field:-1}"

# Set cache update option (default: 10)
UPDATE_CACHE_MINUTES=${opt_update_cache_minutes:-10}

# Define command to cut specific fields
if [[ -z $opt_cut_fields ]]; then
    CUT_FIELDS="cat"
else
    opt_cut_fields=$(p_names_to_indexes "$opt_cut_fields")
    cut_fields_awk=$(echo "$opt_cut_fields" | sed 's/\([0-9][0-9]*\)/$\1/g; s/,/"\\t"/g')
    CUT_FIELDS='awk "{print $cut_fields_awk}"'
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
        find "$cache_filename" -maxdepth 0 -mmin +$UPDATE_CACHE_MINUTES -exec rm '{}' \; 2>/dev/null

        # Read from cache if exists
        if [[ -f "$cache_filename" ]]; then
            cat "$cache_filename"
            return
        fi
    fi

    json_output=""
    while [[ $next_url != null ]]; do
        # Get data
        json_data=$(cf curl "$next_url")
    
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

# Get organizations
next_url="/v2/organizations?results-per-page=100"
json_organizations=$(get_json "$next_url" | jq "{organizations:.}")

if $PRINT_JSON; then
    echo "$json_organizations"
else
    # Generate organization list (tab-delimited)
    organization_list=$(echo "$json_organizations" |\
        jq -r ".organizations[] |
            $POST_FILTER
            [ $P_TO_SHOW | select (. == null) = \"<null>\" | select (. == \"\") = \"<empty>\" ] |
            @tsv")

    # Print headers and organization_list
    (echo $P_TO_SHOW_H | tr ' ' '\t'; echo "$organization_list" | sort -t $'\t' $SORT_OPTIONS | nl -w4) | \
        # Cut fields
        eval $CUT_FIELDS | \
        # Format columns for nice output
        eval $FORMAT_OUTPUT | less --quit-if-one-screen --no-init --chop-long-lines
fi
