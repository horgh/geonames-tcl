package provide geonames 0.1

package require http
package require json
package require tls

namespace eval ::geonames {
	variable search_url https://secure.geonames.org/searchJSON
	variable postalcode_url https://secure.geonames.org/postalCodeSearchJSON
	variable useragent https://github.com/horgh/geonames-tcl
	variable timeout [expr 30*1000]
}

# Parameters:
#
# username: The username to use in API requests.
proc ::geonames::new {username} {
	return [dict create username $username]
}

# Query the search API and return the name, country, latitude, and longitude of
# the first result.
#
# Parameters:
#
# geonames: Create this with ::geonames::new
#
# name: The 'name' parameter for the query
proc ::geonames::search_latlong {geonames name} {
	set response [::geonames::search $geonames $name]

	if {[dict exists $response error]} {
		return $response
	}

	if {![dict exists $response geonames]} {
		# We get errors like status {message {user account not enabled to use the
		# free webservice. Please enable it on your account page:
		# http://www.geonames.org/manageaccount } value 10}
		if {[dict exists $response status message]} {
			return [dict create error [dict get $response status message]]
		}
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

# Query the postalcode API and return the name, country, latitude, and longitude
# of the first result.
#
# Parameters:
#
# geonames: Create this with ::geonames::new
#
# postalcode: The postal code
#
# country: The country
proc ::geonames::postalcode_latlong {geonames postalcode country} {
	set response [::geonames::postalcode $geonames $postalcode $country]

	if {[dict exists $response error]} {
		return $response
	}

	# We get errors like status {message {user account not enabled to use the
	# free webservice. Please enable it on your account page:
	# http://www.geonames.org/manageaccount } value 10}
	if {[dict exists $response status message]} {
		return [dict create error [dict get $response status message]]
	}

	set first [lindex [dict get $response postalCodes] 0]

	# name in JSON -> name to return
	set key_map [dict create \
		placeName   name \
		countryCode countryName \
		lat         lat \
		lng         lng \
	]
	set ret [dict create]
	dict for {key value} $key_map {
		if {![dict exists $first $key]} {
			return [dict create error "no $key found"]
		}

		dict set ret $value [dict get $first $key]
	}

	return $ret
}

# Query the search API.
#
# Parameters:
#
# geonames: Create this with ::geonames::new
#
# query: The 'q' parameter for the query
proc ::geonames::search {geonames query} {
	set query [::http::formatQuery \
		q $query \
		username [dict get $geonames username] \
	]
	set url $::geonames::search_url?$query

	set decoded [::geonames::request $url]

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

# Query the postal code search API.
#
# Parameters:
#
# geonames: Create with ::geonames::new
#
# postalcode: The postal code
#
# country: The country
proc ::geonames::postalcode {geonames postalcode country} {
	set query [::http::formatQuery \
		postalcode $postalcode \
		country $country \
		username [dict get $geonames username] \
	]
	set url $::geonames::postalcode_url?$query

	set decoded [::geonames::request $url]

	# Response looks like:
	# {
	#   "postalCodes": [
	#     {
	#       [..]
	#       "placeName": "<e.g., Tucson>",
	#       "adminName1": "<e.g., Arizona>",
	#       "countryCode": "<e.g., US>",
	#       "lat": "n.nn",
	#       "lng": "-n.nn"
	#     }
	#     [..]
	#    ]
	# }

	return $decoded
}

proc ::geonames::request {url} {
	::http::config -useragent $::geonames::useragent
	::http::register https 443 [list ::tls::socket -ssl2 0 -ssl3 0 -tls1 1]

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

	return $decoded
}
