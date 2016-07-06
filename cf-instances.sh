#!/bin/bash

set -euo pipefail

APP="$1"

GUIDS=$(cf curl "/v2/apps?q=name:${APP}" | jq -r '.resources[].metadata.guid')

for guid in $GUIDS; do
    echo "$APP ($guid)"
    ( cf curl "/v2/apps/$guid/stats" | \
        jq -r '["Index", "IP", "Port"], ( keys[] as $key | [$key, .[$key].stats.host, .[$key].stats.port] ) | @tsv' 2>/dev/null || \
        echo -e '-\t-\t-'
    ) | column -ets$'\t'
    echo
done
