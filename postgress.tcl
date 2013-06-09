# PostgresSQL.tcl --
#
# PostgresSQL connectivity module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::tdao::gdbc::postgres {
}

proc ::tdao::gdbc::postgres::Load {} {
	package require Pgtcl
}

proc ::tdao::gdbc::postgres::open {dbname args} {
	if {[catch {pg_connect $dbname {*}$args} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::gdbc::postgres::close {conn} {
	catch {pg_disconnect $conn}
}

proc ::tdao::gdbc::postgres::get {conn stmt {format "dict"}} {
	if {[catch {pg_exec $conn $stmt} result]} {
		return -code error $result
	}

	set recordslist ""
	switch -- $format {
		dict {
			set recordslist [dict values [pg_result $result -dict]]
		}
		list -
		llist {
			set recordslist [dict values [pg_result $result -$format]]
		}
	}

	pg_result $result -clear
	return $recordslist
}

proc ::tdao::gdbc::postgres::insert {conn stmt {sequence_fields ""}} {
	if {[catch {pg_exec $conn $stmt} result]} {
		return -code error $result
	}

	set status [pg_result $result -status]

	if {$status != "PGRES_COMMAND_OK" && $status != "PGRES_TUPLES_OK"} {
		set error [pg_result $result -error]
		pg_result $result -clear
		return -code error $error
	}

	set numrows [pg_result $result -numTuples]
	if {$numrows} {
		set sequencedict [pg_result $result -dict]		
		pg_result $result -clear
		return [list $numrows [dict get $sequencedict 0]]
	}

	pg_result $result -clear
	return 1
}

proc ::tdao::gdbc::postgres::update {conn stmt} {
	if {[catch {pg_exec $conn $stmt} result]} {
		return -code error $result
	}

	set changes [pg_result $result -cmdTuples]
	pg_result $result -clear
	return $changes
}

proc ::tdao::gdbc::postgres::delete {conn stmt} {
	if {[catch {pg_exec $conn $stmt} result]} {
		return -code error $result
	}

	set changes [pg_result $result -cmdTuples]
	pg_result $result -clear
	return $changes
}

proc ::tdao::gdbc::postgres::begin {conn {lock deferrable}} {
	if {[catch {pg_exec $conn "begin $lock"} result]} {
		return -code error $result
	}
	pg_result $result -clear
}

proc ::tdao::gdbc::postgres::commit {conn} {
	if {[catch {pg_exec $conn commit} result]} {
		return -code error $result
	}
	pg_result $result -clear
}

proc ::tdao::gdbc::postgres::rollback {conn} {
	if {[catch {pg_exec $conn rollback} result]} {
		return -code error $result
	}
	pg_result $result -clear
}

package provide tdao::gdbc::postgres 0.1.0
