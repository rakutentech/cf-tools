# Useful shell scripts for Cloud Foundry API v2

Dependencies:
- jq (>=1.5) and cf commands must be installed
- you must be logged in using "cf login"


## cf-curl.sh
Same as `cf curl` but fetches all pages at once.

Examples:
```
./cf-curl.sh /v2/users
```


## cf-instances.sh
Show list of instances (ip, port and some stats) for a particular application.

Examples:
```
./cf-instances.sh myapp
```


## cf-target-app.sh
Set target org and space using application name

Examples:
```
./cf-target-app.sh myapp
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


## cf-routemappings.sh
Show all Route Mappings for Applications running on Cloud Foundry.

Examples:
```
./cf-routemappings.sh

# Add Organizations and Spaces to the output
join --header -t$'\t' <(./cf-routemappings.sh -Nf App,Route -s App) <(./cf-applist.sh -Nf Name,Organization,Space -s Name) | column -ts$'\t' | less
```

## See also
- Cloud Foundry API v2: https://apidocs.cloudfoundry.org


## Author
[Stanislav German-Evtushenko](https://github.com/giner)
