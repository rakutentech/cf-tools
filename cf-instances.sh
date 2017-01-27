#!/bin/bash

# Show list of instances for a particular application

# Stanislav German-Evtushenko, 2016
# Rakuten inc.

# Dependencies: cf, jq >= 1.5

# Try 'cf curl /v2/apps?q=name:APPNAME' to see what input data looks like

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo Usage: $(basename "$0") "APP_NAME"
    exit 1
fi

APP="$1"

GUIDS=$(cf curl "/v2/apps?q=name:${APP}" | jq -r '.resources[].metadata.guid')

nl=false
for guid in $GUIDS; do
    $nl && echo -ne "\n" || nl=true
    echo "Application: $APP ($guid)"
    ( cf curl "/v2/apps/$guid/stats" | \
        jq -r '["Index", "State", "IP", "Port"],
               ( (keys | sort_by(. | tonumber) | .[]) as $key |
                 [ $key, .[$key].state, .[$key].stats.host, .[$key].stats.port |
                   select (. == null) = "<null>" |
                   select (. == "") = "<empty>"
                 ]
               ) | @tsv' 2>/dev/null || \
        echo -e '-\t-\t-\t-'
    ) | column -ts$'\t'
done
