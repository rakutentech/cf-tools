Operational Tools for RPaaS v2 admins
=====================================

applist.sh
----------
Show all applications running on RPaaS v2.

The script accepts the same sorting options command "sort". Default is "-k1". Example:
```
./applist.sh -nk3
```
Dependencies:
- jq (>=1.5) and cf commands must be installed
- you must be logged in using "cf login"

routelist.sh
----------
Show all routes for applications running on RPaaS v2.

The script accepts the same sorting options command "sort". Default is "-k1". Example:
```
./routelist.sh -nk3
```
Dependencies:
- jq (>=1.5) and cf commands must be installed
- you must be logged in using "cf login"
