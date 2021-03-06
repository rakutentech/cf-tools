# Useful shell scripts for Cloud Foundry API v2 and v3

Dependencies:
- jq (>=1.5) and cf (>=v6.43) commands must be installed
- you must be logged in using "cf login"

# How to install

Make sure you have `git` installed before continue

## Linux 64-bit
```
mkdir -p ~/bin

which cf || { wget -q "https://packages.cloudfoundry.org/stable?release=linux64-binary&source=github" -O - | tar -xzC ~/bin cf && chmod +x ~/bin/cf; }
which jq || { wget -q "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64" -O ~/bin/jq && chmod +x ~/bin/jq; }

git clone https://github.com/rakutentech/cf-tools ~/cf-tools

echo 'PATH="$PATH:$HOME/cf-tools"' >> ~/.profile
source ~/.profile
```

## macOS
```
mkdir -p ~/bin

which cf || { curl -sL "https://packages.cloudfoundry.org/stable?release=macosx64-binary&source=github" | tar -zxC ~/bin cf && chmod +x ~/bin/cf; }
which jq || { curl -sL "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64" -o ~/bin/jq && chmod +x ~/bin/jq; }

echo 'PATH="$HOME/bin:$PATH"' >> ~/.profile

git clone https://github.com/rakutentech/cf-tools ~/cf-tools

echo 'PATH="$PATH:$HOME/cf-tools"' >> ~/.profile
source ~/.profile
```

# How to use

## cf-curl.sh
Same as `cf curl` but fetches all pages at once.

Examples:
```
./cf-curl.sh /v2/users

# Get all events within the last hour (use gdate instead of date on macOS)
./cf-curl.sh -v "/v2/events?results-per-page=100&q=timestamp>$(date -u +%FT%TZ --date="1 hour ago")"
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


## cf-target-route.sh
Set target org and space using route

Examples:
```
./cf-target-route.sh myroute
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

# Add Organizations and Spaces to the output (works well only when application names across organizations and spaces are unique)
join --header -t$'\t' <(./cf-routemappings.sh -Nf App,Route -s App) <(./cf-applist.sh -Nf Name,Organization,Space -s Name) | column -ts$'\t' | less
```

## cf-bg-restart.sh
Restart or restage an application without downtime (blue-green restart / restage).

WARNING: It is recommended to do simulation in test environment before using this command.

What you also should keep in mind when using this command:
- GUID of application changes (which also means that `cf events` are lost)
- Specific to restart only (not restage): droplet will lose information about which bits were used for its generation (`cf curl /v3/apps/$(cf app MY_APP --guid)/droplets/current | jq .links.package` will be null),
  which is not a problem unless you use other tools relying on this information

Examples:
```
./cf-bg-restart.sh APP_NAME
./cf-bg-restart.sh -r -s cflinuxfs3 APP_NAME
```

## See also
- Cloud Foundry API v2: https://apidocs.cloudfoundry.org
- Cloud Foundry API v3: http://v3-apidocs.cloudfoundry.org


## Author
[Stanislav German-Evtushenko](https://github.com/giner)
