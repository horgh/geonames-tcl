lappend ::auto_path .

package require geonames

proc ::main {} {
	global argv
	if {[llength $argv] != 2} {
		::print_usage
		return 0
	}
	set username [lindex $argv 0]
	set query [lindex $argv 1]

	set geonames [::geonames::new $username]
	set res [::geonames::latlong $geonames $query]
	puts "$query: $res"

	return 1
}

proc ::print_usage {} {
	global argv0
	puts "Usage: $argv0 <username> <search query>"
}

if {[::main]} {
	return 0
}
return 1
