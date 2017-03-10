#!/bin/bash

# cf-instances.sh - Show list of instances for a particular application
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

# Dependencies: cf, jq >= 1.5

# Run 'cf curl /v2/apps?q=name:APPNAME' to see what input data looks like

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
        jq -r 'def bytes_to_megabytes_str(bytes):
                     bytes / pow(1024;2) * 10 |
                     floor / 10 |
                     tostring
               ;

               def number_to_percent_str(number):
                     number * 1000 |
                     floor / 10 |
                     tostring
               ;

               ["Index", "State", "IP", "Port", "CPU", "Mem", "Mem_Quota", "Disk", "Disk_Quota"],
               ( (keys | sort_by(. | tonumber) | .[]) as $key |
                 [ $key,
                   .[$key].state,
                   .[$key].stats.host,
                   .[$key].stats.port,
                   number_to_percent_str(.[$key].stats.usage.cpu) + "%",
                   bytes_to_megabytes_str(.[$key].stats.usage.mem) + "M",
                   bytes_to_megabytes_str(.[$key].stats.mem_quota) + "M",
                   bytes_to_megabytes_str(.[$key].stats.usage.disk) + "M",
                   bytes_to_megabytes_str(.[$key].stats.disk_quota) + "M" |
                     select (. == null) = "<null>" |
                     select (. == "") = "<empty>"
                 ]
               ) | @tsv' 2>/dev/null || \
        echo -e '-\t-\t-\t-\t-\t-\t-\t-\t-'
    ) | column -ts$'\t'
done
