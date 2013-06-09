# mariadb.tcl --
#
# MariaDB/MySQL connecitivity module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ----------------------------------------------------------------------
# class tdbo::MariaDB
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::MariaDB {
	inherit tdbo::Database
# ----------------------------------------------------------------------
# constructor:
#
#
#
# ----------------------------------------------------------------------
constructor {} {
	package require mysqltcl
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
# method - open - Open a database connection.
#
#
#
# ----------------------------------------------------------------------
public method open {dbname args} {
	if {[info exists conn] && $conn != ""} {
		return -code error "An opened connection already exists."
	}

	if {[catch {mysql::connect {*}$args} result]} {
		return -code error $result
	}

	set conn $result
	if {[catch {mysql::use $conn $dbname} result]} {
		catch {mysql::close $conn}
		unset conn
		return -code error $result
	}

	return $conn
}


# ----------------------------------------------------------------------
# method - close - Close the database connection.
#
#
#
# ----------------------------------------------------------------------
public method close {} {
	if {![info exists conn]} {
		return
	}

	catch {mysql::close $conn}
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
	if {[catch {mysql::exec $conn $sqlscript} result]} {
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


# ----------------------------------------------------------------------
#
# method - update - update record(s) of a table/view
#
#
# ----------------------------------------------------------------------
public method update {schema_name namevaluepairs {condition ""}} {
	set sqlscript [_prepare_update_stmt $schema_name $namevaluepairs $condition]
	if {[catch {mysql::exec $conn $sqlscript} result]} {
		return -code error $result
	}

	return $result
}


# ----------------------------------------------------------------------
#
# method - delete - delete record(s) from a table/view
#
#
# ----------------------------------------------------------------------
public method delete {schema_name {condition ""}} {
	set sqlscript [_prepare_delete_stmt $schema_name $condition]
	if {[catch {mysql::exec $conn $sqlscript} result]} {
		return -code error $result
	}

	return $result
}


# ----------------------------------------------------------------------
#
# method - begin a database transaction.
#
#
# ----------------------------------------------------------------------
public method begin {{isolation "repeatable read"}} {
	set sqlscript "set transaction isolation level $isolation"
	if {[catch {mysql::exec $conn $sqlscript} result]} {
		return -code error $result
	}
	set sqlscript "start transaction"
	if {[catch {mysql::exec $conn $sqlscript} result]} {
		return -code error $result
	}
}


# ----------------------------------------------------------------------
#
# method - commit the database transaction.
#
#
# ----------------------------------------------------------------------
public method commit {} {
	set sqlscript "commit;\n"
	if {[catch {mysql::exec $conn $sqlscript} result]} {
		return -code error $result
	}
}


# ----------------------------------------------------------------------
# method - rollback the database transaction.
#
# args   - none. 
#
# ----------------------------------------------------------------------
public method rollback {} {
	set sqlscript "rollback;\n"
	if {[catch {mysql::exec $conn $sqlscript} result]} {
		return -code error $result
	}
}


# ----------------------------------------------------------------------
# variable conn: Variable to hold database connection object
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
	if {[catch {mysql::sel $conn $sqlscript -list} result]} {
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


# ------------------------------END-------------------------------------
}
