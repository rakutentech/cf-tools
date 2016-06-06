#!/bin/bash

# Show list of Applications running on Cloud Foundry

# Stanislav German-Evtushenko, 2016
# Rakuten inc.

# Dependencies: cf, jq >= 1.5

# Try 'cf curl /v2/apps' to see what input data looks like

set -euo pipefail

SORT_OPTIONS=${@:--k1}

PROPERTIES_TO_SHOW_H='# Name State Memory Instances Disk_quota Stack Organization Space Created Updated App_URL Routes_URL Buildpack Detected_Buildpack'
PROPERTIES_TO_SHOW='.entity.name, .entity.state, .entity.memory, .entity.instances, .entity.disk_quota, .extra.stack, .extra.organization, .extra.space, .metadata.created_at, .metadata.updated_at, .metadata.url, .entity.routes_url, .entity.buildpack, .entity.detected_buildpack'

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

# Get stacks
next_url="/v2/stacks?results-per-page=100"
json_stacks=$(get_json "$next_url" | jq "{stacks:.}")

# Get applications
next_url="/v2/apps?results-per-page=100"
json_apps=$(get_json "$next_url" | jq "{apps:.}")

# Add extra data to json_spaces
json_spaces=$(echo "$json_organizations"$'\n'"$json_spaces" | \
     jq -s '. | add' | \
     jq '.organizations as $organizations |
         .spaces[] |= (.extra.organization = $organizations[.entity.organization_guid].entity.name) |
         .spaces | {spaces:.}')

# Add extra data to json_apps
json_apps=$(echo "$json_stacks"$'\n'"$json_spaces"$'\n'"$json_apps" | \
     jq -s '. | add' | \
     jq '.stacks as $stacks |
         .spaces as $spaces |
         .apps[] |= (.extra.stack = $stacks[.entity.stack_guid].entity.name |
                     .extra.organization = $spaces[.entity.space_guid].extra.organization |
                     .extra.space = $spaces[.entity.space_guid].entity.name ) |
         .apps | {apps:.}')

# Generate application list (tab-delimited)
app_list=$(echo "$json_apps" |\
    jq -r ".apps[] | [ $PROPERTIES_TO_SHOW | select (. == null) = \"<null>\" | select (. == \"\") = \"<empty>\" ] | @tsv")

# Print headers and app_list
(echo $PROPERTIES_TO_SHOW_H | tr ' ' '\t'; echo "$app_list" | sort -t $'\t' $SORT_OPTIONS | nl -w4) | \
    # Format columns for nice output
    column -ts $'\t' | less --quit-if-one-screen --no-init --chop-long-lines
