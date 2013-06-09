# postgres.tcl --
#
# PostgreSQL connectivity module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ----------------------------------------------------------------------
# class tdbo::PostgreSQL
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::PostgreSQL {
	inherit tdbo::Database
# ----------------------------------------------------------------------
# constructor:
#
#
#
# ----------------------------------------------------------------------
constructor {} {
	package require Pgtcl
}


# ----------------------------------------------------------------------
# destructor
#
#
#
# ----------------------------------------------------------------------
destructor {
}


# ----------------------------------------------------------------------
#
# method - open - Open a database connection.
#
#
# ----------------------------------------------------------------------
public method open {dbname args} {
	if {[info exists conn] && $conn != ""} {
		return -code error "An opened connection already exists."
	}

	if {[catch {pg_connect $dbname {*}$args} result]} {
		return -code error $result
	}

	set conn $result
	return $conn
}


# ----------------------------------------------------------------------
#
# method - close - Close the database connection.
#
#
# ----------------------------------------------------------------------
public method close {} {
	if {![info exists conn]} {
		return
	}

	catch {pg_disconnect $conn}
	unset conn
}


# ----------------------------------------------------------------------
#
# method - get - get a record from table/view
#
# format: one of "dict", "list"
# ----------------------------------------------------------------------
public method get {schema_name fieldslist condition {format "dict"}} {
	return [_select $schema_name  $fieldslist $format -condition [_prepare_condition $condition]]
}

# ----------------------------------------------------------------------
#
# method - mget - get multiple records from table/view
#
# format: one of "dict", "llist", "list" 
# ----------------------------------------------------------------------
public method mget {schema_name fieldslist {format "dict"} args} {
	return [_select $schema_name $fieldslist $format {*}$args]
}


# ----------------------------------------------------------------------
#
# method - insert - insert a record into table/view
#
#
# ----------------------------------------------------------------------
public method insert {schema_name namevaluepairs {sequence_fields ""}} {
	set sqlscript [_prepare_insert_stmt $schema_name $namevaluepairs]
	if {[catch {pg_exec $conn $sqlscript} result]} {
		return -code error $result
	}

	set status [pg_result $result -status]
${log}::debug "insert status: $status"

	if {$status != "PGRES_COMMAND_OK" && $status != "PGRES_TUPLES_OK"} {
		set error [pg_result $result -error]
		pg_result $result -clear
		return -code error $error
	}

	set numrows [pg_result $result -numTuples]
${log}::debug "insert numrows: $numrows"
	if {$numrows} {
		set sequencedict [pg_result $result -dict]		
${log}::debug "insert sequencedict: $sequencedict"
		pg_result $result -clear
		return [list $numrows [dict get $sequencedict 0]]
	}

	pg_result $result -clear
	return 1
}


# ----------------------------------------------------------------------
#
# method - update - update record(s) of a table/view
#
#
# ----------------------------------------------------------------------
public method update {schema_name namevaluepairs {condition ""}} {
	set sqlscript [_prepare_update_stmt $schema_name $namevaluepairs $condition]
	if {[catch {pg_exec $conn $sqlscript} result]} {
		return -code error $result
	}

	set changes [pg_result $result -cmdTuples]
	pg_result $result -clear
	return $changes
}


# ----------------------------------------------------------------------
#
# method - delete - delete record(s) from a table/view
#
#
# ----------------------------------------------------------------------
public method delete {schema_name {condition ""}} {
	set sqlscript [_prepare_delete_stmt $schema_name $condition]
	if {[catch {pg_exec $conn $sqlscript} result]} {
		return -code error $result
	}

	set changes [pg_result $result -cmdTuples]
	pg_result $result -clear
	return $changes
}


# ----------------------------------------------------------------------
#
# method - begin a database transaction.
#
#
# ----------------------------------------------------------------------
public method begin {{lock deferrable}} {
	if {[catch {pg_exec $conn "begin $lock"} result]} {
		return -code error $result
	}
	pg_result $result -clear
}


# ----------------------------------------------------------------------
#
# method - commit the database transaction.
#
#
# ----------------------------------------------------------------------
public method commit {} {
	if {[catch {pg_exec $conn commit} result]} {
		return -code error $result
	}
	pg_result $result -clear
}


# ----------------------------------------------------------------------
#
# method - rollback the database transaction.
#
#
# ----------------------------------------------------------------------
public method rollback {} {
	if {[catch {pg_exec $conn rollback} result]} {
		return -code error $result
	}
	pg_result $result -clear
}


# ----------------------------------------------------------------------
# variable conn: Variable to hold database connection.
#
#
#
# ----------------------------------------------------------------------
protected variable conn


# ----------------------------------------------------------------------
#
#
# format: one of "dict", "llist", "list" 
#
# ----------------------------------------------------------------------
private method _select {schema_name fieldslist {format "dict"} args} {
	set sqlscript [_prepare_select_stmt $schema_name $fieldslist {*}$args]
	if {[catch {pg_exec $conn $sqlscript} result]} {
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


# ------------------------------END-------------------------------------
}
