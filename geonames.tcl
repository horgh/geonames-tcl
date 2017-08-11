package provide geonames 0.1

package require http
package require json
package require tls

namespace eval ::geonames {
	variable url https://secure.geonames.org/searchJSON
	variable useragent https://github.com/horgh/geonames-tcl
	variable timeout [expr 30*1000]
}

# Parameters:
#
# username: The username to use in API requests.
proc ::geonames::new {username} {
	return [dict create username $username]
}

# Query the search API.
#
# Parameters:
#
# geonames: Create this with ::geonames::new
#
# query: The 'q' parameter for the query
proc ::geonames::search {geonames query} {
	::http::config -useragent $::geonames::useragent
	::http::register https 443 [list ::tls::socket -ssl2 0 -ssl3 0 -tls1 1]

	set query [::http::formatQuery \
		q $query \
		username [dict get $geonames username] \
	]
	set url $::geonames::url?$query
	set token [::http::geturl $url -timeout $::geonames::timeout -binary 1]

	set status [::http::status $token]
	if {$status != "ok"} {
		::http::cleanup $token
		return [dict create error "status is $status"]
	}

	set ncode [::http::ncode $token]

	if {$ncode != 200} {
		::http::cleanup $token
		return [dict create error "HTTP status $ncode"]
	}

	set data [::http::data $token]
	set data [encoding convertfrom "utf-8" $data]
	::http::cleanup $token

	set decoded [::json::json2dict $data]

	# Response looks like:
	# {
	#   "totalResultsCount": n,
	#   "geonames": [
	#     {
	#       [..]
	#       "name": "<e.g. a city>",
	#       "countryName": "<e.g., a country>",
	#       "lat": "n.nn",
	#       "lng": "-n.nn"
	#     }
	#     [..]
	#    ]
	# }

	return $decoded
}

# Query the search API and return the name, country, latitude, and longitude of
# the first result.
#
# Parameters:
#
# geonames: Create this with ::geonames::new
#
# name: The 'name' parameter for the query
proc ::geonames::latlong {geonames name} {
	set response [::geonames::search $geonames $name]

	if {[dict exists $response error]} {
		return $response
	}

	if {![dict exists $response geonames]} {
		return [dict create error "no results found"]
	}

	set first [lindex [dict get $response geonames] 0]

	set keys [list name countryName lat lng]
	set ret [dict create]
	foreach key $keys {
		if {![dict exists $first $key]} {
			return [dict create error "no $key found"]
		}
		dict set ret $key [dict get $first $key]
	}

	return $ret
}
