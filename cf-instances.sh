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
    echo "Usage: $(basename "$0") APP_NAME"
    echo "       $(basename "$0") APP_GUID"
    exit 1
fi

APP="$1"
APP_URLENCODED=$(echo "$APP" | jq -Rr @uri)

GUIDS=$(cf curl "/v2/apps?q=name:${APP_URLENCODED}" | jq -r '.resources[].metadata.guid')

# Add application name to the list of GUIDS if it looks like GUID
HEX='[0-9a-fA-F]'
if [[ $APP =~ ^$HEX{8}-$HEX{4}-$HEX{4}-$HEX{4}-$HEX{12}$ ]]; then
    GUIDS="$APP"${GUIDS:+$'\n'}"$GUIDS"
fi

nl=false
for guid in $GUIDS; do
    $nl && echo -ne "\n" || nl=true
    appname=$(cf curl "/v2/apps/$guid" | jq -r '.entity.name // "<null>"')
    echo "Application: $appname ($guid)"
    ( cf curl "/v2/apps/$guid/stats" | \
        jq -r 'def bytes_to_megabytes_str(bytes):
                     if bytes != null then
                       bytes / pow(1024;2) * 10 + 0.5 |
                       floor / 10 |
                       tostring + "M"
                     else
                       null
                     end
               ;

               def number_to_percent_str(number):
                     if number !=null then
                       number * 1000 + 0.5 |
                       floor / 10 |
                       tostring + "%"
                     else
                       null
                     end
               ;
               def seconds_to_seconds_str(seconds):
                     if seconds != null then
                       seconds |
                       tostring + "s"
                     else
                       null
                     end
               ;

               ["Index", "State", "Uptime", "IP", "Port", "CPU", "Mem", "Mem_Quota", "Disk", "Disk_Quota"],
               ( (keys | sort_by(. | tonumber) | .[]) as $key |
                 [ $key,
                   .[$key].state,
                   seconds_to_seconds_str(.[$key].stats.uptime),
                   .[$key].stats.host,
                   .[$key].stats.port,
                   number_to_percent_str(.[$key].stats.usage.cpu),
                   bytes_to_megabytes_str(.[$key].stats.usage.mem),
                   bytes_to_megabytes_str(.[$key].stats.mem_quota),
                   bytes_to_megabytes_str(.[$key].stats.usage.disk),
                   bytes_to_megabytes_str(.[$key].stats.disk_quota) |
                     select (. == null) = "<null>" |
                     select (. == "") = "<empty>"
                 ]
               ) | @tsv' 2>/dev/null || \
        echo -e '-\t-\t-\t-\t-\t-\t-\t-\t-\t-'
    ) | column -ts$'\t'
done
