# mariadb.tcl --
#
# MariaDB/MySQL connectivity module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::tdao::dbc::mariadb {
}

proc ::tdao::dbc::mariadb::Load {} {
	package require mysqltcl
}

proc ::tdao::dbc::mariadb::open {dbname args} {
	if {[catch {mysql::connect {*}$args} result]} {
		return -code error $result
	}

	set conn $result
	if {[catch {mysql::use $conn $dbname} result]} {
		catch {mysql::close $conn}
		return -code error $result
	}

	return $conn
}

proc ::tdao::dbc::mariadb::close {conn} {
	catch {mysql::close $conn}
}

proc ::tdao::dbc::mariadb::get {conn stmt fieldslist {format "dict"}} {
	if {[catch {mysql::sel $conn $stmt -list} result]} {
		return -code error $result
	}

	set recordslist ""
	switch -- $format {
		dict {
			foreach row $result {
				set record ""
				foreach field $fieldslist val $row {
					lappend record $field $val
				}
				lappend recordslist $record
			}
		}
		llist {
			set recordslist $result
		}
		list {
			set recordslist [join $result]
		}
	}
	return $recordslist
}

proc ::tdao::dbc::mariadb::insert {conn stmt {sequence_fields ""}} {
	if {[catch {mysql::exec $conn $stmt} result]} {
		return -code error $result
	}

	set status 1
	if {$sequence_fields == ""} {
		return $status
	}

	set sequence_values [dict create]
	set rowid [mysql::insertid $conn]
	foreach fname $sequence_fields {
		dict set sequence_values $fname $rowid
	}

	return [list $status $sequence_values]
}

proc ::tdao::dbc::mariadb::update {conn stmt} {
	if {[catch {mysql::exec $conn $stmt} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dbc::mariadb::delete {conn stmt} {
	if {[catch {mysql::exec $conn $stmt} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dbc::mariadb::begin {conn {isolation "repeatable read"}} {
	set stmt "set transaction isolation level $isolation"
	if {[catch {mysql::exec $conn $stmt} result]} {
		return -code error $result
	}
	set stmt "start transaction"
	if {[catch {mysql::exec $conn $stmt} result]} {
		return -code error $result
	}
}

proc ::tdao::dbc::mariadb::commit {conn} {
	set stmt "commit;\n"
	if {[catch {mysql::exec $conn $stmt} result]} {
		return -code error $result
	}
}

proc ::tdao::dbc::mariadb::rollback {conn} {
	set stmt "rollback;\n"
	if {[catch {mysql::exec $conn $stmt} result]} {
		return -code error $result
	}
}

package provide tdao::dbc::mariadb 0.1.1
