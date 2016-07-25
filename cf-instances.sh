#!/bin/bash

set -euo pipefail

APP="$1"

GUIDS=$(cf curl "/v2/apps?q=name:${APP}" | jq -r '.resources[].metadata.guid')

nl=false
for guid in $GUIDS; do
    $nl && echo -ne "\n" || nl=true
    echo "Application: $APP ($guid)"
    ( cf curl "/v2/apps/$guid/stats" | \
        jq -r '["Index", "State", "IP", "Port"],
               ( keys[] as $key |
                 [ $key, .[$key].state, .[$key].stats.host, .[$key].stats.port |
                   select (. == null) = "<null>" |
                   select (. == "") = "<empty>"
                 ]
               ) | @tsv' 2>/dev/null || \
        echo -e '-\t-\t-\t-'
    ) | column -ets$'\t'
done
