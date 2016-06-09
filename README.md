Operational Tools for RPaaS v2 admins
=====================================

applist.sh
----------
Show all applications running on RPaaS v2.

Examples:
```
./applist.sh -s "-nk3"
./applist.sh -c60 -f1,2,3,4,5,8,10
```
Dependencies:
- jq (>=1.5) and cf commands must be installed
- you must be logged in using "cf login"

routelist.sh
----------
Show all routes for applications running on RPaaS v2.

Examples:
```
./routelist.sh -s "-nk3"
./routelist.sh -c60 -f1,2,3,4,5,8,10
```
Dependencies:
- jq (>=1.5) and cf commands must be installed
- you must be logged in using "cf login"
