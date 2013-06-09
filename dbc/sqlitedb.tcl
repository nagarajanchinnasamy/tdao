# sqlitedb.tcl --
#
# sqlite3 connectivity module.
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.


package require tdao::dbc 0.1.0

# ----------------------------------------------------------------------
# class SQLite
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::SQLite {
	inherit tdbo::Database
# ----------------------------------------------------------------------
# constructor:
#
#
#
# ----------------------------------------------------------------------
constructor {} {
	package require sqlite3
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
public method open {location {initscript ""}} {
	if {[info exists conn] && $conn != ""} {
		return -code error "An opened connection already exists."
	}

	incr conncount
	set conn sqlite_$conncount
	if {[catch {sqlite3 $conn $location} err]} {
		unset conn
		return -code error $err
	}

	if {$initscript != ""} {
		$conn eval $initscript
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

	catch {$conn close}
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
	if {[catch {$conn eval $sqlscript} result]} {
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


# ----------------------------------------------------------------------
#
# method - update - update record(s) of a table/view
#
#
# ----------------------------------------------------------------------
public method update {schema_name namevaluepairs {condition ""}} {
	set sqlscript [_prepare_update_stmt $schema_name $namevaluepairs $condition]
	if {[catch {$conn eval $sqlscript} err]} {
		return -code error $err
	}

	return [$conn changes]
}


# ----------------------------------------------------------------------
#
# method - delete - delete record(s) from a table/view
#
#
# ----------------------------------------------------------------------
public method delete {schema_name {condition ""}} {
	set sqlscript [_prepare_delete_stmt $schema_name $condition]
	if {[catch {$conn eval $sqlscript} err]} {
		return -code error $err
	}

	return [$conn changes]
}


# ----------------------------------------------------------------------
#
# method - begin a database transaction.
#
#
# ----------------------------------------------------------------------
public method begin {{lock deferred}} {
	$conn eval begin $lock
}


# ----------------------------------------------------------------------
#
# method - commit the database transaction.
#
# ----------------------------------------------------------------------
public method commit {} {
	$conn eval commit
}


# ----------------------------------------------------------------------
#
# method - rollback the database transaction.
#
#
# ----------------------------------------------------------------------
public method rollback {} {
	$conn eval rollback
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
# format: one of "dict", "llist", "list" 
#
# ----------------------------------------------------------------------
private method _select {schema_name fieldslist {format "dict"} args} {
	set sqlscript [_prepare_select_stmt $schema_name $fieldslist {*}$args]

	set recordslist ""
	switch -- $format {
		dict {
			if {[catch {
				$conn eval $sqlscript record {
					array unset record "\\*"
					lappend recordslist [array get record]
				}} err]} {
				return -code error $err
			}
		}
		llist {
			if {[catch {
				$conn eval $sqlscript record {
					array unset record "\\*"
					lappend recordslist [dict values [array get record]]
				}} err]} {
				return -code error $err
			}
		}
		list {
			if {[catch {$conn eval $sqlscript} result]} {
				return -code error $result
			}
			set recordslist $result 
		}
	}

	return $recordslist
}


# ------------------------------END-------------------------------------
}
