#!/bin/bash

# Show list of Routes for applications running on Cloud Foundry

# Stanislav German-Evtushenko, 2016
# Rakuten inc.

# Dependencies: cf, jq >= 1.5

# Try 'cf curl /v2/routes' to see what input data looks like

set -euo pipefail

# Cache json data for X minutes
# Set as "" to disable caching
CACHE_FOR_X_MIN="10"

# Default sorting options (See 'man sort')
SORT_OPTIONS=${@:--k1}

PROPERTIES_TO_SHOW_H='# Host Domain Path Organization Space Created Updated Route_URL Apps_URL'
PROPERTIES_TO_SHOW='.entity.host, .extra.domain, .entity.path, .extra.organization, .extra.space, .metadata.created_at, .metadata.updated_at, .metadata.url, .entity.apps_url'

get_json () {
    next_url="$1"

    next_url_hash=$(echo "$next_url" | $(which md5sum || which md5))
    cache_filename="/tmp/.$(basename "$0").$(id -u).$next_url_hash"

    if [[ -n $CACHE_FOR_X_MIN ]]; then
        # Remove expired cache file
        find "$cache_filename" -maxdepth 0 -mmin +$CACHE_FOR_X_MIN -exec rm '{}' \; 2>/dev/null

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
        json_output=$(echo "${json_output}"$'\n'"$output" | jq -s "add")
    
        # Get URL for next page of results
        next_url=$(echo "$json_data" | jq .next_url -r)
    done
    echo "$json_output"

    # Update cache file
    if [[ -n $CACHE_FOR_X_MIN ]]; then
        echo "$json_output" > "$cache_filename"
    fi
}

# Get organizations
next_url="/v2/organizations?results-per-page=100"
json_organizations=$(get_json "$next_url" | jq "{organizations:.}")

# Get spaces
next_url="/v2/spaces?results-per-page=100"
json_spaces=$(get_json "$next_url" | jq "{spaces:.}")

# Get routes
next_url="/v2/routes?results-per-page=100"
json_routes=$(get_json "$next_url" | jq "{routes:.}")

# Get domains
next_url="/v2/domains?results-per-page=100"
json_domains=$(get_json "$next_url" | jq "{domains:.}")

# Add extra data to json_spaces
json_spaces=$(echo "$json_organizations"$'\n'"$json_spaces" | \
     jq -s '. | add' | \
     jq '.organizations as $organizations |
         .spaces[] |= (.extra.organization = $organizations[.entity.organization_guid].entity.name) |
         .spaces | {spaces:.}')

# Add extra data to json_routes
json_routes=$(echo "$json_spaces"$'\n'"$json_domains"$'\n'"$json_routes" | \
     jq -s '. | add' | \
     jq '.spaces as $spaces |
         .domains as $domains |
         .routes[] |= (.extra.organization = $spaces[.entity.space_guid].extra.organization |
                       .extra.space = $spaces[.entity.space_guid].entity.name |
                       .extra.domain = $domains[.entity.domain_guid].entity.name ) |
         .routes| {routes:.}')

# Generate route list (tab-delimited)
route_list=$(echo "$json_routes" |\
    jq -r ".routes[] | [ $PROPERTIES_TO_SHOW | select (. == null) = \"<null>\" | select (. == \"\") = \"<empty>\" ] | @tsv")

# Print headers and route_list
(echo $PROPERTIES_TO_SHOW_H | tr ' ' '\t'; echo "$route_list" | sort -t $'\t' $SORT_OPTIONS | nl -w4) | \
    # Format columns for nice output
    column -ts $'\t' | less --quit-if-one-screen --no-init --chop-long-lines
