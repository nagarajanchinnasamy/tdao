# dbc.tcl --
#
# Database Connectivity module
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::tdao {}

namespace eval ::tdao::dbc {
	variable commands
	set commands [list load]

	variable driver_commands
	set driver_commands [list open]

	variable conn_commands
	set conn_commands [list insert get mget update delete begin commit rollback close]

	variable drivers
	set drivers [dict create]

	variable connections
	set connections [dict create -count 0]

	namespace export dbc
}

proc ::tdao::dbc::dbc {cmd args} {
    variable commands

	if {[lsearch $commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $commands ,]"
	}

    set cmd [string totitle "$cmd"]
    return [uplevel 1 ::tdao::dbc::${cmd} $args]
}

proc ::tdao::dbc::Load {driver {version ""}} {
	variable drivers

	if {[dict exists $drivers $driver]} {
		return [dict get $dbms $driver -cmd]
	}

	if {[catch {package require tdao::dbc::${driver} {*}$version} err]} {
		return -code error "Unable to load dbc driver $driver.\nError: $err"
	}
	
	if {[catch {[namespace current]::${driver}::Load} err]} {
		return -code error "Unable to load dbc driver $driver.\nError: $err"
	}

	set driver_cmd [format "%s%s%s" [namespace current] "___" $driver]
    uplevel #0 [list interp alias {} $driver_cmd {} [namespace current]::DriverCmd $driver]

	dict set drivers $driver -cmd $driver_cmd 

    return $driver_cmd
}

proc ::tdao::dbc::DriverCmd {driver cmd args} {
	variable driver_commands

	if {[lsearch $driver_commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $driver_commands ,]"
	}

	return [uplevel 1 [namespace current]::${cmd} $driver $args]
}

proc ::tdao::dbc::open {driver args} {
	variable drivers
	variable connections

	if {![dict exists $drivers $driver]} {
		return -code error "GDBC driver $driver not loaded"
	}


	dict incr connections -count
	set conn_cmd [format "%s%s" "::tdao::dbc::conncmd" [dict get $connections -count]]


	if {[catch {uplevel 1 [namespace current]::${driver}::open $args} result]} {
		return -code error $result
	}
	set conn $result

    uplevel #0 [list interp alias {} $conn_cmd {} [namespace current]::ConnCmd $conn_cmd]

    dict set connections $conn_cmd -driver $driver
    dict set connections $conn_cmd -conn $conn

    return $conn_cmd
}

proc ::tdao::dbc::ConnCmd {conn_cmd cmd args} {
	variable connections
	variable conn_commands

	if {![dict exists $connections $conn_cmd]} {
		return -code error "Connection $conn_cmd does not exist"
	}

	if {[lsearch $conn_commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $conn_commands ,]"
	}

	set driver [dict get $connections $conn_cmd -driver]
	set conn [dict get $connections $conn_cmd -conn]

	if {$cmd == "close"} {
		return [uplevel 1 [namespace current]::${cmd} $conn_cmd $driver $conn $args]
	}

	return [uplevel 1 [namespace current]::${cmd} $driver $conn $args]	
}

proc ::tdao::dbc::close {conn_cmd driver conn} {
	variable connections

	if {[catch {uplevel 1 [namespace current]::${driver}::close $conn} err]} {
		return -code error $err
	}

	if {[dict exists $connections $conn_cmd]} {
		dict unset connections $conn_cmd
	}
}

proc ::tdao::dbc::get {driver conn schema_name fieldslist condition {format "dict"}} {
	set stmt [_prepare_select_stmt $schema_name $fieldslist -condition [_prepare_condition $condition]]
	if {[catch {uplevel 1 [list [namespace current]::${driver}::get $conn $stmt $fieldslist $format]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dbc::mget {driver conn schema_name fieldslist {format "dict"} args} {
	set stmt [_prepare_select_stmt $schema_name $fieldslist {*}$args]]
	if {[catch {uplevel 1 [list [namespace current]::${driver}::get $conn $stmt $fieldslist $format]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dbc::insert {driver conn schema_name namevaluepairs {sequence_fields ""}} {
	set stmt [_prepare_insert_stmt $schema_name $namevaluepairs]
	if {[catch {uplevel 1 [list [namespace current]::${driver}::insert $conn $stmt $sequence_fields]} result]} {
		return -code error $result
	}

	return $result		
}

proc ::tdao::dbc::update {driver conn schema_name namevaluepairs {condition ""}} {
	set stmt [_prepare_update_stmt $schema_name $namevaluepairs $condition]
	if {[catch {uplevel 1 [list [namespace current]::${driver}::update $conn $stmt]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dbc::delete {driver conn schema_name {condition ""}} {
	set stmt [_prepare_delete_stmt $schema_name $condition]
	if {[catch {uplevel 1 [list [namespace current]::${driver}::delete $conn $stmt]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dbc::begin {driver conn args} {
	if {[catch {uplevel 1 [list [namespace current]::${driver}::begin $conn {*}$args]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dbc::commit {driver conn args} {
	if {[catch {uplevel 1 [list [namespace current]::${driver}::commit $conn {*}$args]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dbc::rollback {driver conn args} {
	if {[catch {uplevel 1 [list [namespace current]::${driver}::rollback $conn {*}$args]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dbc::_prepare_insert_stmt {schema_name namevaluepairs} {
	set fnamelist [join [dict keys $namevaluepairs] ", "]
	set valuelist [list]
	foreach value [dict values $namevaluepairs] {
		lappend valuelist '$value'
	} 
	set valuelist [join $valuelist ", "]

	set stmt "INSERT INTO $schema_name ($fnamelist) VALUES ($valuelist)"
	return $stmt
}

proc ::tdao::dbc::_prepare_select_stmt {schema_name fieldslist args} {
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

proc ::tdao::dbc::_prepare_update_stmt {schema_name namevaluepairs {condition ""}} {
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

proc ::tdao::dbc::_prepare_delete_stmt {schema_name {condition ""}} {
	set stmt "DELETE FROM $schema_name"
	if {[string length $condition]} {
		append stmt " WHERE [_prepare_condition $condition]"
	}

	return $stmt
}

proc ::tdao::dbc::_prepare_condition {conditionlist} {
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

proc ::tdao::dbc::_qualify {item {level 2}} {

    if {![string match "::*" "$item"]} {
        set ns [uplevel $level [list namespace current]]

        if {![string match "::" "$ns"]} {
            append ns "::"
        }
     
        set item "$ns${item}"
    }

    return "$item"

}

namespace eval ::tdao {
    # Get 'dbc::dbc' into the general structure namespace.
    namespace import -force dbc::dbc
    namespace export dbc
}

package provide tdao::dbc 0.1.1
