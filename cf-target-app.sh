#!/bin/bash

# cf-target-app.sh - Set target org and space using application name
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

# Run 'cf curl /v2/apps?q=name:APPNAME' to see what input data looks like

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $(basename "$0") APP_NAME"
    echo "       $(basename "$0") APP_GUID"
    exit 1
fi

APP="$1"
APP_URLENCODED=$(echo "$APP" | jq -Rr @uri)


# Get all GUIDS
GUIDS=$(cf curl "/v2/apps?q=name:${APP_URLENCODED}" | jq -r '.resources[].metadata.guid')

# Add application name to the list of GUIDS if it looks like GUID
HEX='[0-9a-fA-F]'
if [[ $APP =~ ^$HEX{8}-$HEX{4}-$HEX{4}-$HEX{4}-$HEX{12}$ ]]; then
    GUIDS="$APP"${GUIDS:+$'\n'}"$GUIDS"
    APP="$APP ($(cf curl "/v2/apps/$APP" | jq -r '.entity.name // "<null>"'))"
fi

# Get all targets
if [[ -z $GUIDS ]]; then
    echo "ERROR: There are no targets for ${APP}" >&2
    exit 1
fi
targets=$(
    for guid in $GUIDS; do
        app_entry=$(cf curl "/v2/apps/$guid")

        space_url=$(echo "$app_entry" | jq -r '.entity.space_url')
        space_entry=$(cf curl "$space_url")
        space_name=$(echo "$space_entry" | jq -r '.entity.name')

        org_url=$(echo "$space_entry" | jq -r '.entity.organization_url')
        org_name=$(cf curl "$org_url" | jq -r '.entity.name')

        echo -e "$guid\t$org_name\t$space_name"
    done
)


# Prompt
echo "Targets for $APP:"
echo
(echo -e "#\tGUID\tOrganization\tSpace"; echo "$targets" | nl -w4) | column -ts$'\t'
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
