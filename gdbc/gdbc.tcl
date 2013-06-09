# gdbc.tcl --
#
# Generic Database Connectivity module
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::tdao {}

namespace eval ::tdao::gdbc {
	variable commands
	set commands [list load]

	variable driver_commands
	set driver_commands [list open]

	variable conn_commands
	set conn_commands [list add get mget save delete close]

	variable drivers
	set drivers [dict create]

	variable connections
	set connections [dict create -count 0]

	namespace export gdbc
}

proc ::tdao::gdbc::gdbc {cmd args} {
    variable commands

	if {[lsearch $commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $commands ,]"
	}

    set cmd [string totitle "$cmd"]
    return [uplevel 1 ::tdao::gdbc::${cmd} $args]
}

proc ::tdao::gdbc::Load {driver {version ""}} {
	variable drivers

	if {[dict exists $drivers $driver]} {
		return [dict get $dbms $driver -cmd]
	}

	if {[catch {package require tdao::gdbc::${driver} {*}$version} err]} {
		return -code error "Unable to load gdbc driver $driver.\nError: $err"
	}
	
	if {[catch {[namespace current]::${driver}::Load} err]} {
		return -code error "Unable to load gdbc driver $driver.\nError: $err"
	}

	set driver_cmd [format "%s%s%s" [namespace current] "___" $driver]
    uplevel #0 [list interp alias {} $driver_cmd {} [namespace current]::DriverCmd $driver]

	dict set drivers $driver -cmd $driver_cmd 

    return $driver_cmd
}

proc ::tdao::gdbc::DriverCmd {driver cmd args} {
	variable driver_commands

	if {[lsearch $driver_commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $driver_commands ,]"
	}

	return [uplevel 1 [namespace current]::${cmd} $driver $args]
}

proc ::tdao::gdbc::open {driver conn args} {
	variable drivers
	variable connections

	if {![dict exists $drivers $driver]} {
		return -code error "GDBC driver $driver not loaded"
	}

	if {$conn == "#auto"} {
		set count [expr [dict get $connections -count] + 1]
		set conn_cmd [format "%s%s" "::tdao::gdbc::conncmd" $count]
	} else {
		set conn_cmd [_qualify $conn]
	}

	if {[dict exists $connections $conn_cmd]} {
		return -code error "Connection $conn is already open"
	}
	
	set conn [format "%s%s" $conn_cmd "___conn"]

	if {[catch {uplevel 1 [namespace current]::${driver}::open ${conn} $args} result]} {
		return -code error $result
	}

    uplevel #0 [list interp alias {} $conn_cmd {} [namespace current]::ConnCmd $conn_cmd]

    dict set connections -count $count
    dict set connections $conn_cmd -driver $driver
    dict set connections $conn_cmd -conn $conn

    return $conn_cmd
}

proc ::tdao::gdbc::ConnCmd {conn_cmd cmd args} {
	variable connections
	variable connection_commands

	if {![dict exists $connections $conn_cmd]} {
		return -code error "Connection $conn_cmd does not exist"
	}

	if {[lsearch $connection_commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $connection_commands ,]"
	}

	set driver [dict get $connections $conn_cmd -driver]
	set conn [dict get $connections $conn_cmd -conn]

	if {$cmd == "close"} {
		return [uplevel 1 [namespace current]::${cmd} $conn_cmd $driver $conn $args]
	}

	return [uplevel 1 [namespace current]::${cmd} $driver $conn $args]	
}

proc ::tdao::gdbc::close {conn_cmd driver conn} {
	variable connections

	if {[catch {uplevel 1 [namespace current]::${driver}::close $conn $stmt $format} err]} {
		return -code error $err
	}

	if {[dict exists $connctions $conn_cmd]} {
		dict unset connections $conn_cmd
	}
}

proc ::tdao::gdbc::get {driver conn schema_name fieldslist condition {format "dict"}} {
	set stmt [_prepare_select_stmt $schema_name $fieldslist -condition [_prepare_condition $condition]]
	if {[catch {uplevel 1 [namespace current]::${driver}::get $conn $stmt $format} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::gdbc::mget {driver conn schema_name fieldslist {format "dict"} args} {
	set stmt [_prepare_select_stmt $schema_name $fieldslist {*}$args]]
	if {[catch {uplevel 1 [namespace current]::${driver}::get $conn $stmt $format} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::gdbc::insert {driver conn schema_name namevaluepairs {sequence_fields ""}} {
	set stmt [_prepare_insert_stmt $schema_name $namevaluepairs $sequence_fields]
	if {[catch {uplevel 1 [namespace current]::${driver}::insert $conn $stmt} result]} {
		return -code error $result
	}

	return $result		
}

proc ::tdao::gdbc::update {driver conn schema_name namevaluepairs {condition ""}} {
	set stmt [_prepare_update_stmt $schema_name $namevaluepairs $condition]
	if {[catch {uplevel 1 [namespace current]::${driver}::update $conn $stmt} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::gdbc::delete {driver conn schema_name {condition ""}} {
	set stmt [_prepare_delete_stmt $schema_name $condition]
	if {[catch {uplevel 1 [namespace current]::${driver}::delete $conn $stmt} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::gdbc::begin {driver conn args} {
	if {[catch {uplevel 1 [namespace current]::${driver}::begin $conn {*}$args} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::gdbc::commit {driver conn args} {
	if {[catch {uplevel 1 [namespace current]::${driver}::commit $conn {*}$args} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::gdbc::rollback {driver conn args} {
	if {[catch {uplevel 1 [namespace current]::${driver}::rollback $conn {*}$args} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::gdbc::_prepare_insert_stmt {schema_name namevaluepairs} {
	set fnamelist [join [dict keys $namevaluepairs] ", "]
	set valuelist [list]
	foreach value [dict values $namevaluepairs] {
		lappend valuelist '$value'
	} 
	set valuelist [join $valuelist ", "]

	set stmt "INSERT INTO $schema_name ($fnamelist) VALUES ($valuelist)"
	return $stmt
}

proc ::tdao::gdbc::_prepare_select_stmt {schema_name fieldslist args} {
	set fieldslist [join $fieldslist ", "]

	set condition ""
	set groupby ""
	set orderby ""
	foreach {opt val} $args {
		switch $opt {
			-condition {
				set condition $val
			}
			-groupby {
				set groupby $val
			}
			-orderby {
				set orderby $val
			}
			default {
				return -code error "Unknown option: $opt"
			}
		}
	}
	set stmt "SELECT $fieldslist FROM $schema_name"
	if [string length $condition] {
		append stmt " WHERE $condition"
	}
	if [string length $groupby] {
		append stmt " GROUP BY $groupby"
	}
	if [string length $orderby] {
		append stmt " ORDER BY $orderby"
	}

	return $stmt
}

proc ::tdao::gdbc::_prepare_update_stmt {schema_name namevaluepairs {condition ""}} {
	set setlist ""
	foreach {name val} $namevaluepairs {
		lappend setlist "$name='$val'"
	}
	set setlist [join $setlist ", "]

	set stmt "UPDATE $schema_name SET $setlist"
	if [string length $condition] {
		append stmt " WHERE [_prepare_condition $condition]"
	}

	return $stmt
}

proc ::tdao::gdbc::_prepare_delete_stmt {schema_name {condition ""}} {
	set stmt "DELETE FROM $schema_name"
	if {[string length $condition]} {
		append stmt " WHERE [_prepare_condition $condition]"
	}

	return $stmt
}

proc ::tdao::gdbc::_prepare_condition {conditionlist} {
	set sqlcondition [list]
	foreach condition $conditionlist {
		set complist [list]
		foreach {fname val} $condition {
			lappend complist "$fname='$val'"
		}
		if {$complist != ""} {
			lappend sqlcondition "([join $complist " AND "])"
		}
	}

	if {$sqlcondition == ""} {
		return
	}

	set sqlcondition [join $sqlcondition " OR "]
	return "($sqlcondition)"
}

package provide tdao::gdbc 0.1.0