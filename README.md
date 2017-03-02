# Useful shell scripts for Cloud Foundry API v2

Dependencies:
- jq (>=1.5) and cf commands must be installed
- you must be logged in using "cf login"


## cf-curl.sh
Same as `cf curl` but fetches all pages at once.


## cf-instances.sh
Show list of instances for a particular application.

Examples:
```
cf-instances.sh myapp
```


## cf-applist.sh
Show all applications running on Cloud Foundry.

Examples:
```
./cf-applist.sh -S Memory
./cf-applist.sh -c60 -f "#,Name,State,Memory,Instances,Organization,Created"
```


## cf-routelist.sh
Show all routes for applications running on Cloud Foundry.

Examples:
```
./cf-routelist.sh -s Created
./cf-routelist.sh -c60 -f "#,Host,Domain,Path,Organization,Space,Created"
```


## cf-orglist.sh
Show all organizations created on Cloud Foundry.

Examples:
```
./cf-orglist.sh
./cf-orglist.sh -c10080 -f "#,Name,Status,Created"
```


## See also
- Cloud Foundry API v2: https://apidocs.cloudfoundry.org


## Author
[Stanislav German-Evtushenko](https://github.com/giner)
