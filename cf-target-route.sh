#!/bin/bash

# cf-target-route.sh - Set target org and space using route
# Copyright (C) 2017  Rakuten, Inc.
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

# Run 'cf curl /v2/routes' to see what input data looks like

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo Usage: $(basename "$0") "ROUTE"
    exit 1
fi

ROUTE="$1"


# Parse the route
if [[ $ROUTE =~ ^(([^ .]+)\.)?([^ /:]+)(:([0-9]+))?(/([^ ]+))?$ ]]; then
    host=${BASH_REMATCH[2]}
    domain=${BASH_REMATCH[3]}
    port=${BASH_REMATCH[5]:-0}
    path=${BASH_REMATCH[6]}
else
    echo "ERROR: Unable to parse the route $ROUTE" >&2
    exit 1
fi


# Get the route GUID
domain_guid=$(
    (
        cf curl "/v2/shared_domains?q=name:${host}.${domain}"
        cf curl "/v2/private_domains?q=name:${host}.${domain}"
    ) |
    jq -r '.resources[].metadata.guid'
)
if [[ -n $domain_guid ]]; then
    host=""
else
    domain_guid=$(
        (
            cf curl "/v2/shared_domains?q=name:${domain}"
            cf curl "/v2/private_domains?q=name:${domain}"
        ) |
        jq -r '.resources[].metadata.guid'
    )
fi
route_guid=$(
    cf curl "/v2/routes?q=host:${host}&q=domain_guid:${domain_guid}&q=port:${port}&q=path:${path}" |
        jq -r '.resources[].metadata.guid'
)


# Get all targets
GUIDS="$route_guid"
if [[ -z $GUIDS ]]; then
    echo "ERROR: There are no targets for ${ROUTE}" >&2
    exit 1
fi
targets=$(
    for guid in $GUIDS; do
        route_entry=$(cf curl "/v2/routes/$guid")

        space_url=$(echo "$route_entry" | jq -r '.entity.space_url')
        space_entry=$(cf curl "$space_url")
        space_name=$(echo "$space_entry" | jq -r '.entity.name')

        org_url=$(echo "$space_entry" | jq -r '.entity.organization_url')
        org_name=$(cf curl "$org_url" | jq -r '.entity.name')

        echo -e "$guid\t$org_name\t$space_name"
    done
)


# Prompt
echo "Targets:"
echo
echo "$targets" | column -ts$'\t' | nl
echo
read -p "Please choose the target [1]: " target_n; target_n=${target_n:-1}


# Set the target
targets_total=$(echo "$targets" | wc -l)
if [[ $target_n -lt 1 ]] || [[ $target_n -gt $targets_total ]]; then
    echo "ERROR: Oops, there is no such an option" >&2
    exit 1
else
    target=$(echo "$targets" | sed -n "${target_n}p")
    target_org=$(echo "$target" | cut -f2)
    target_space=$(echo "$target" | cut -f3)
    cf target -o "$target_org" -s "$target_space"
fi
