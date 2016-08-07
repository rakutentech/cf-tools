Operational Tools for RPaaS v2 admins
=====================================

cf-applist.sh
----------
Show all applications running on RPaaS v2.

Examples:
```
./cf-applist.sh -S Memory
./cf-applist.sh -c60 -f "#,Name,State,Memory,Instances,Organization,Created"
```
Dependencies:
- jq (>=1.5) and cf commands must be installed
- you must be logged in using "cf login"

cf-routelist.sh
----------
Show all routes for applications running on RPaaS v2.

Examples:
```
./cf-routelist.sh -s Created
./cf-routelist.sh -c60 -f "#,Host,Domain,Path,Organization,Space,Created"
```
Dependencies:
- jq (>=1.5) and cf commands must be installed
- you must be logged in using "cf login"

cf-orglist.sh
----------
Show all organizations created on RPaaS v2.

Examples:
```
./cf-orglist.sh
./cf-orglist.sh -c10080 -f "#,Name,Status,Created"
```
Dependencies:
- jq (>=1.5) and cf commands must be installed
- you must be logged in using "cf login"
