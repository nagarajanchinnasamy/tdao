# database.tcl --
#
# Generic Database interface that needs to be implemented by
# database connectivity modules (eg., sqlite, mysql, oracle etc.)
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ----------------------------------------------------------------------
# class Database
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::Database {
	inherit tdbo::Object
# ----------------------------------------------------------------------
# constructor:
#
#
#
# ----------------------------------------------------------------------
constructor {} {
	if {[namespace tail [info class]] == "Database"} {
		return -code error "Error: Can't create Database objects - abstract class."
	}
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
# method  : open - First method to be invoked on a Database object to
#           establish connection.
# args    : variable no. of arguments, defined by the underlying
#           database implementation such as SQLite.
# returns : connection object command that will be used to invoke data
#           access commands such as get, add, save and delete.
# ----------------------------------------------------------------------
public method open {args}


# ----------------------------------------------------------------------
# method  : close - To close the database connection.
# args    : none
# returns : none
#
# ----------------------------------------------------------------------
public method close {}


# ----------------------------------------------------------------------
# method  : get - Retrieve a single record from a table/view          
# args    : schema_name - name of the table/view
#           condition   - list of dictionaries. Every dictionary contains
#                         name-value pairs that will be joined with an
#                         AND operator. The list elements are joined
#                         with an OR operator. For e.g., the list:
#
#                          {{f1 val1 f2 val2} {f1 val3 f2 val4}}
#
#                         is translated into:
#
#                          ((f1='val1' AND f2='val2') OR
#                                (f1='val3' AND f2='va	l4'))
#           fieldslist  - optional list of fields to be retrieved
#
# returns : a record as a dict with fieldname-value pairs
#
# ----------------------------------------------------------------------
public method get {schema_name fieldslist condition {format "dict"}}


# ----------------------------------------------------------------------
# method  : mget        - Retrieve multiple records from a table/view           
# args    : schema_name - name of the table/view
#           args        - variable no. of arguments as defined by
#                         specific database implementation.
# returns : list of lists with each list having a fieldname-value pair
#           that can be constructed into a dict
#
# ----------------------------------------------------------------------
public method mget {schema_name fieldslist {format "dict"} args}


# ----------------------------------------------------------------------
# method  : insert         - insert a record into table/view           
# args    : schema_name    - name of the table/view
#           namevaluepairs - a dict containing fieldname-value pairs
#           sequence_fields- optional list of fieldnames that are
#                            auto-incremented by insert operation.
# returns : list containing two elements. First element is the status of
#           insert operation and the second a dict of
#           sequence_fieldname-value pairs.
#
# ----------------------------------------------------------------------
public method insert {schema_name namevaluepairs {sequence_fields ""}}


# ----------------------------------------------------------------------
# method  : update         - update one or more records in a table/view           
# args    : schema_name    - name of the table/view
#           namevaluepairs - a dict containing fieldname-value pairs
#           condition   - list of dictionaries. Every dictionary contains
#                         name-value pairs that will be joined with an
#                         AND operator. The list elements are joined
#                         with an OR operator. For e.g., the list:
#
#                          {{f1 val1 f2 val2} {f1 val3 f2 val4}}
#
#                         is translated into:
#
#                          ((f1='val1' AND f2='val2') OR
#                                (f1='val3' AND f2='va	l4'))
#
# returns : status of the update operation.
#
# ----------------------------------------------------------------------
public method update {schema_name namevaluepairs {condition ""}}


# ----------------------------------------------------------------------
# method  : delete         - delete one or more records from a table/view           
# args    : schema_name    - name of the table/view
#           condition   - list of dictionaries. Every dictionary contains
#                         name-value pairs that will be joined with an
#                         AND operator. The list elements are joined
#                         with an OR operator. For e.g., the list:
#
#                          {{f1 val1 f2 val2} {f1 val3 f2 val4}}
#
#                         is translated into:
#
#                          ((f1='val1' AND f2='val2') OR
#                                (f1='val3' AND f2='va	l4'))
# returns : status of delete operation.
#
# ----------------------------------------------------------------------
public method delete {schema_name {condition ""}}


# ----------------------------------------------------------------------
# method  : begin  - begin a database transaction
# args    : args   - variable no. of arguments as defined by a specific
#                    database implementation
# returns : status of begin operation
#
# ----------------------------------------------------------------------
public method begin {args}


# ----------------------------------------------------------------------
# method  : commit - commit current database transaction
# args    : args   - variable no. of arguments as defined by a specific
#                    database implementation
# returns : status of commit operation
#
# ----------------------------------------------------------------------
public method commit {args}


# ----------------------------------------------------------------------
# method  : rollback - roll back current transaction without commiting 
# args    : args     - variable no. of arguments as defined by a specific
#                      database implementation
# returns : status of rollback operation
#
# ----------------------------------------------------------------------
public method rollback {args}


# ----------------------------------------------------------------------
# method  : 
# args    : 
# 
# returns :
#
# ----------------------------------------------------------------------
protected method _prepare_insert_stmt {schema_name namevaluepairs} {
	set fnamelist [join [dict keys $namevaluepairs] ", "]
	set valuelist [list]
	foreach value [dict values $namevaluepairs] {
		lappend valuelist '$value'
	} 
	set valuelist [join $valuelist ", "]

	set stmt "INSERT INTO $schema_name ($fnamelist) VALUES ($valuelist)"
	${log}::debug $stmt
	return $stmt
}


# ----------------------------------------------------------------------
# method  : 
# args    : 
# 
# returns :
#
# ----------------------------------------------------------------------
protected method _prepare_select_stmt {schema_name fieldslist args} {
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

	${log}::debug $stmt
	return $stmt
}


# ----------------------------------------------------------------------
# method  : 
# args    : 
# 
# returns :
#
# ----------------------------------------------------------------------
protected method _prepare_update_stmt {schema_name namevaluepairs {condition ""}} {
	set setlist ""
	foreach {name val} $namevaluepairs {
		lappend setlist "$name='$val'"
	}
	set setlist [join $setlist ", "]

	set stmt "UPDATE $schema_name SET $setlist"
	if [string length $condition] {
		append stmt " WHERE [_prepare_condition $condition]"
	}

	${log}::debug $stmt
	return $stmt
}


# ----------------------------------------------------------------------
# method  : 
# args    : 
# 
# returns :
#
# ----------------------------------------------------------------------
protected method _prepare_delete_stmt {schema_name {condition ""}} {
	set stmt "DELETE FROM $schema_name"
	if {[string length $condition]} {
		append stmt " WHERE [_prepare_condition $condition]"
	}

	${log}::debug $stmt
	return $stmt
}

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method _prepare_condition {conditionlist} {
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

# -------------------------END------------------------------------------
}
