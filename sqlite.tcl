# sqlitedb.tcl --
#
# sqlite3 connectivity module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::tdao::dbc::sqlite {
	variable count 0
}

proc ::tdao::dbc::sqlite::Load {} {
	package require sqlite3
}

proc ::tdao::dbc::sqlite::open {location {initscript ""}} {
	incr count
	set conn [format "%s%s%s" [namespace current] "___conn" $count]
	if {[catch {sqlite3 $conn $location} err]} {
		return -code error $err
	}

	if {$initscript != ""} {
		uplevel 1 $conn eval $initscript
	}

	return $conn
}

proc ::tdao::dbc::sqlite::close {conn} {
	catch {$conn close}
}

proc ::tdao::dbc::sqlite::get {conn stmt fieldslist {format "dict"}} {
	set recordslist ""
	switch -- $format {
		dict {
			if {[catch {
				$conn eval $stmt record {
					array unset record "\\*"
					lappend recordslist [array get record]
				}} err]} {
				return -code error $err
			}
		}
		llist {
			if {[catch {
				$conn eval $stmt record {
					array unset record "\\*"
					lappend recordslist [dict values [array get record]]
				}} err]} {
				return -code error $err
			}
		}
		list {
			if {[catch {$conn eval $stmt} result]} {
				return -code error $result
			}
			set recordslist $result 
		}
	}

	return $recordslist
}

proc ::tdao::dbc::sqlite::insert {conn stmt {sequence_fields ""}} {
	if {[catch {$conn eval $stmt} result]} {
		return -code error $result
	}

	set status [$conn changes]
	if {$sequence_fields == ""} {
		return $status
	}

	set sequence_values [dict create]
	set rowid [$conn last_insert_rowid]
	foreach fname $sequence_fields {
		dict set sequence_values $fname $rowid
	}

	return [list $status $sequence_values]
}

proc ::tdao::dbc::sqlite::update {conn stmt} {
	if {[catch {$conn eval $stmt} err]} {
		return -code error $err
	}

	return [$conn changes]
}

proc ::tdao::dbc::sqlite::delete {conn stmt} {
	if {[catch {$conn eval $stmt} err]} {
		return -code error $err
	}

	return [$conn changes]
}

proc ::tdao::dbc::sqlite::begin {conn {lock deferred}} {
	$conn eval begin $lock
}

proc ::tdao::dbc::sqlite::commit {conn} {
	$conn eval commit
}

proc ::tdao::dbc::sqlite::rollback {conn} {
	$conn eval rollback
}

package provide tdao::dbc::sqlite 0.1.0
