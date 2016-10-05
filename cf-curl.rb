#!/usr/bin/env ruby
# cfcurl is like cf curl, but fetches ALL pages instead of just the first one
# usage: cfcurl <url>
# example: cfcurl /v2/apps
require 'json'

url = ARGV.shift
res = []
page = 1
STDERR.print "fetching page #{page}\r"
while url do
  cfres = `cf curl '#{url}'` or throw "empty response from cf"
  cfres = JSON.load(cfres) or throw "broken response from cf"
  res += cfres["resources"]
  url = cfres["next_url"]
  page += 1
  STDERR.print "fetching page #{page} of #{cfres["total_pages"]}\r"
end

puts JSON.pretty_generate({
  "total_results" => res.length,
  "total_pages" => 1,
  "prev_url" => nil,
  "next_url" => nil,
  "resources" => res
})
