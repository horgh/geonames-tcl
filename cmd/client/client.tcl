lappend ::auto_path .

package require geonames

proc ::main {} {
	global argv

	if {[llength $argv] < 2} {
		::print_usage
		return 0
	}
	set command [lindex $argv 1]

	if {$command == "search"} {
		return [::search $argv]
	}

	if {$command == "postalcode"} {
		return [::postalcode $argv]
	}

	::print_usage
	return 0
}

proc ::print_usage {} {
	global argv0

	puts "Usage: $argv0 <username> <command> \[parameters\]"
	puts ""
	puts "Command is one of: search, postalcode"
	puts ""
	puts "Parameters:"
	puts "  search: <query>"
	puts "  postalcode: <postal code> <country>"
}

proc ::search {argv} {
	if {[llength $argv] != 3} {
		::print_usage
		return 0
	}

	set username [lindex $argv 0]
	set query [lindex $argv 2]

	set geonames [::geonames::new $username]
	set res [::geonames::search_latlong $geonames $query]
	puts "$query: $res"

	return 1
}

proc ::postalcode {argv} {
	if {[llength $argv] != 4} {
		::print_usage
		return 0
	}

	set username [lindex $argv 0]
	set postalcode [lindex $argv 2]
	set country [lindex $argv 3]

	set geonames [::geonames::new $username]
	set res [::geonames::postalcode_latlong $geonames $postalcode $country]
	puts "$postalcode ($country): $res"

	return 1
}

if {[::main]} {
	return 0
}
return 1
