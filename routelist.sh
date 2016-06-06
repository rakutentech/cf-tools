#!/bin/bash

# Show list of Routes for applications running on Cloud Foundry

# Stanislav German-Evtushenko, 2016
# Rakuten inc.

# Dependencies: cf, jq >= 1.5

# Try 'cf curl /v2/routes' to see what input data looks like

set -euo pipefail

SORT_OPTIONS=${@:--k1}

PROPERTIES_TO_SHOW_H='# Host Domain Path Organization Space Created Updated Apps_URL'
PROPERTIES_TO_SHOW='.entity.host, .extra.domain, .entity.path, .extra.organization, .extra.space, .metadata.created_at, .metadata.updated_at, .entity.apps_url'

get_json () {
    next_url="$1"
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
