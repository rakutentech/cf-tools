Operational Tools for RPaaS v2 admins
=====================================

applist.sh
----------
Show all applications running on RPaaS v2.

Examples:
```
./applist.sh -S Memory
./applist.sh -c60 -f "#,Name,State,Memory,Instances,Organization,Created"
```
Dependencies:
- jq (>=1.5) and cf commands must be installed
- you must be logged in using "cf login"

routelist.sh
----------
Show all routes for applications running on RPaaS v2.

Examples:
```
./routelist.sh -s Created
./routelist.sh -c60 -f "#,Host,Domain,Path,Organization,Space,Created"
```
Dependencies:
- jq (>=1.5) and cf commands must be installed
- you must be logged in using "cf login"

orglist.sh
----------
Show all organizations created on RPaaS v2.

Examples:
```
./orglist.sh
./orglist.sh -c10080 -f "#,Name,Status,Created"
```
Dependencies:
- jq (>=1.5) and cf commands must be installed
- you must be logged in using "cf login"
