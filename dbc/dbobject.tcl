# dbobject.tcl --
#
# Data Object Interface that needs to be inherited by
# application-specific object classes (eg., Employee, PurchaseItem etc.)
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ----------------------------------------------------------------------
# class DBObject
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::DBObject {
	inherit tdbo::Object

# ----------------------------------------------------------------------
# method - constructor - Stores the definition of primary keys, unique
#                        fields and sequence / auto-increment fields by
#                        invoking following (optional) protected methods
#                        in the derived class:
#		                     _define_primarykey
#		                     _define_unique
#		                     _define_autoincrement
#                        Also prepares list of fieldnames to be used by
#                        insert and update operations later.
#                        
# args   - db - instance of a specific Database implementation
#               such as SQLite
#
# ----------------------------------------------------------------------
constructor {db} {
	if {[namespace tail [info class]] == "DBObject"} {
		return -code error "Error: Can't create DBObject objects - abstract class."
	}
	if {$db == "" || ![$db isa tdbo::Database]} {
		return -code error "Invalid db object type"
	}
	set [itcl::scope db] $db
	if ![llength [array names fields -glob "$clsName,*"]] {
		_define_primarykey
		_define_unique
		_define_autoincrement
		__prepare_getfields
		__prepare_insertfields
		__prepare_updatefields
	}
}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
destructor {}


# ----------------------------------------------------------------------
# proc    : schema_name - method to be implemented by derived classes that
#                      returns the name of the table/view
# args    : none
#
# returns : name of the table/view the derived class represents
#
# ----------------------------------------------------------------------
public proc schema_name {}


# ----------------------------------------------------------------------
# method : add - Insert the object into database. In preparing the record
#                to insert, this method prepares a list of name-value
#                pairs, by default, from the public member variables of
#                the object. However, if the argument args is passed, it
#                uses only those field names in the args-list in
#                preparing the name-value pairs.
#
#                While preparing the name-value pairs, it includes only
#                those member variables that are initialized with a
#                value other than <undefined>. In Itcl, Member variables
#                that are not initialized are internally identified with
#                the value <undefined>. Instead of an empty string, we
#                make use of this state of a member variable to
#                indicate the absense of a field in the insert
#                operation (thus resulting in NULL value in the
#                database).
#
#                Upon successful completion of add The new values of
#                sequence / auto incremented fields are updated back
#                into the object.
#
#                Returns the status of add operation as a numerical
#                value. Non-zero value indicates success.
# ----------------------------------------------------------------------
public method add {args} {
	if {$args == ""} {
		set namevaluepairs [__make_namevaluepairs $fields($clsName,insertlist)]
	} else {
		set namevaluepairs [__make_namevaluepairs $args]
	}

	if {[catch {$db insert [${clsName}::schema_name] $namevaluepairs $fields($clsName,sqlist)} result]} {
		${log}::error $result
		return 0
	}
		
	lassign $result status sequencevalues

	if {$status} {
		if {$sequencevalues != ""} {
			set sequencecfg [dict create]
			dict for {fname val} $sequencevalues {
				dict set sequencecfg -${fname} $val
			}
			$this configure {*}$sequencecfg
		}
	}
	return $status
}


# ----------------------------------------------------------------------
# method : get - Retrieve a record from the database and populate
#                object's member variables with values retrieved.
#
#                By default, this method retrieves all the fields of a
#                record from the database, identifed by the public
#                member variables. However, if the argument args is
#                passed with a list of field names (corresponding to its
#                public member variables) then only those fields are
#                retrieved and populated into the object.
#
#                The record to be retrieved is identified by the values
#                of primary key or unique member variables of the
#                object. For e.g., if the primary key was defined as
#                {pk1 pk2} and unique fields are defined as
#                {{uq1} {uq2 uq3}} then the condition to identify the
#                record to retrieve will be:
#
#                   ((pk1=pk1value and pk2=pk2vaue) or (uq1=uq1value) or
#                        (uq2=uq2value and uq3=uq3value))
#
#                If any of the key field in the primary key or unique
#                fields is uninitialized, then those fields are not
#                included in the condition. For e.g., if pk1 is
#                uninitialized (i.e., having the value <undefined>),
#                then the condition will be:
#
#                   ((uq1=uq1value) or (uq2=uq2value and uq3=uq3value))
#
#                Or, for e.g., if uq2 is uninitialized, then the
#                condition will be:
#
#                   ((pk1=pk1value and pk2=pk2vaue) or (uq1=uq1value))
#
#                Or, for e.g., if uq1 is uninitialized, then the
#                condition will be:
#
#                   ((pk1=pk1value and pk2=pk2vaue) or
#                        (uq2=uq2value and uq3=uq3value))
#
#                If the condition results into a retrieval of more than
#                one record, then this method returns an error.
#
#                Upon successful execution, in addition to populating
#                the member variables, this method returns the
#                name-value pairs retrieved from database as a dict. If
#                the retrieval does not return any record from database,
#                then the result will be an empty string. 
#
# ----------------------------------------------------------------------
public method get {args} {
	set fieldslist $fields($clsName,getlist)
	if {$args != ""} {
		set fieldslist $args
	}

	if {[catch {$db get [${clsName}::schema_name] $fieldslist [__get_condition] dict} result]} {
		return -code error $result
	}
	if {[llength $result] > 1} {
		return -code error "Multiple records retrieved in get operation"
	}

	set objcfg [dict create]
	dict for {fname val} [lindex $result 0] {
		dict set objcfg "-$fname" "$val"
	}
		
	if {[dict size $objcfg]} {
		$this configure {*}[dict get $objcfg]
	}

	return $objcfg
}


# ----------------------------------------------------------------------
# method : save - save the object into database. In preparing the record
#                 to save, this method prepares a list of name-value
#                 pairs, by default, from the public member variables of
#                 the object. However, if the argument args is passed,
#                 it uses only those field names in the args-list in
#                 preparing the name-value pairs.
#
#                 While preparing the name-value pairs, it includes only
#                 those member variables that are initialized with a
#                 value other than <undefined>. In Itcl, Member
#                 variables that are not initialized are internally
#                 identified with the value <undefined>. Instead of an
#                 empty string, we make use of this state of a member
#                 variable to indicate the absense of a field in the
#                 update operation (thus not affecting those fields in
#                 the database).
#
#                 The record to be updated in the database is identified
#                 by the values of primary key or unique member
#                 variables of the object. For e.g., if the primary key
#                 was defined as {pk1 pk2} and unique fields are defined
#                 as {{uq1} {uq2 uq3}} then the condition to identify
#                 the record to retrieve will be:
#
#                   ((pk1=pk1value and pk2=pk2vaue) or (uq1=uq1value) or
#                        (uq2=uq2value and uq3=uq3value))
#
#                 If any of the key field in the primary key or unique
#                 fields is uninitialized, then those fields are not
#                 included in the condition. For e.g., if pk1 is
#                 uninitialized (i.e., having the value <undefined>),
#                 then the condition will be:
#
#                   ((uq1=uq1value) or (uq2=uq2value and uq3=uq3value))
#
#                 Or, for e.g., if uq2 is uninitialized, then the
#                 condition will be:
#
#                   ((pk1=pk1value and pk2=pk2vaue) or (uq1=uq1value))
#
#                 Or, for e.g., if uq1 is uninitialized, then the
#                 condition will be:
#
#                   ((pk1=pk1value and pk2=pk2vaue) or
#                        (uq2=uq2value and uq3=uq3value))
#
#
#                 Upon successful completion of add The new values of
#                 sequence / auto incremented fields are updated back
#                 into the object.
#
#                Returns the status of add operation as a numerical
#                value. Non-zero value indicates success.
# ----------------------------------------------------------------------
public method save {args} {
	if {$args == ""} {
		set namevaluepairs [__make_namevaluepairs $fields($clsName,updatelist)]
	} else {
		set namevaluepairs [__make_namevaluepairs $args]
	}

	if {[catch {$db update [${clsName}::schema_name] $namevaluepairs [__get_condition]} result]} {
		return -code error $result
	}

	return $result
}


# ----------------------------------------------------------------------
# method : delete - delete the record represented by the object in
#                   database and reset the object values.
#
#                   The record to be deleted in the database is
#                   identified by the values of primary key or unique
#                   member variables of the object. For e.g., if the
#                   primary key was defined as {pk1 pk2} and unique
#                   fields are defined as {{uq1} {uq2 uq3}} then the
#                   condition to identify the record to delete will be:
#
#                   ((pk1=pk1value and pk2=pk2vaue) or (uq1=uq1value) or
#                        (uq2=uq2value and uq3=uq3value))
#
#                   If any of the key field in the primary key or unique
#                   fields is uninitialized, then those fields are not
#                   included in the condition. For e.g., if pk1 is
#                   uninitialized (i.e., having the value <undefined>),
#                   then the condition will be:
#
#                   ((uq1=uq1value) or (uq2=uq2value and uq3=uq3value))
#
#                   Or, for e.g., if uq2 is uninitialized, then the
#                   condition will be:
#
#                   ((pk1=pk1value and pk2=pk2vaue) or (uq1=uq1value))
#
#                   Or, for e.g., if uq1 is uninitialized, then the
#                   condition will be:
#
#                   ((pk1=pk1value and pk2=pk2vaue) or
#                        (uq2=uq2value and uq3=uq3value))
#
#                   Returns the status of delete operation as a numerical
#                   value. Non-zero value indicates success.
# ----------------------------------------------------------------------
public method delete {} {
	if {[catch {$db delete [${clsName}::schema_name] [__get_condition]} result]} {
		return -code error $result
	}

	if {$result} {
		clear
	}

	return $result
}


# ----------------------------------------------------------------------
# method : _mget - Helper routine to retrieve multiple records from a
#                  table / view. This proc is to be invoked from within
#                  mget proc of a class derived from DBObject.
#
# args   : schema_name - name of the table/view
#          db    - Specific tdbo::Database implementation object
#          args  - A dict of options. This proc consumes optional
#                  -format option from this dict. Other options are
#                  passed to db object for processing.
#
#                  Allowed values for -format option are:
#                      dict - Indicates that the records retrieved are
#                             to be returned as a list of dictionaries.
#                             A dictionary contains field-name-value
#                             pairs of a record.
#
#                      list - Indicates that the records retrieved are
#                             to be returned as a list of lists. A list
#                             contains only the values of the fields
#                             in a record.
#
#                  The default value for -format option is: dict
#
# returns : Records as defined by -format option.
# ----------------------------------------------------------------------
protected proc _mget {db schema_name fieldslist {format dict} args} {

	if {$db == "" || ![$db isa tdbo::Database]} {
		return -code error "Invalid db object type"
	}

	if {[catch {$db mget $schema_name $fieldslist $format {*}$args} result]} {
		return -code error $result
	}

	if {$format == "dict"} {
		foreach record  $records {
			set objconfig [dict create]
			dict for {fname val} $record {
				dict set objconfig "-$fname" "$val"
			}
			lappend result $objconfig
		}
	}

	return $result
}


# ----------------------------------------------------------------------
# method  : define_primarykey - method to be invoked by derived classes
#                               from within _define_primarykey method.
# args    : a list of fieldnames that constitute the primary key
#
# returns : none
# ----------------------------------------------------------------------
protected method define_primarykey {args} {
	set fields($clsName,pklist) [list {*}$args]
}


# ----------------------------------------------------------------------
# method  : define_unque - method to be invoked by derived classes
#                          from within _define_primarykey method.
# args    : a list of lists with each list containing fieldnames that
#           constitute a unique key
#
# returns : none
# ----------------------------------------------------------------------
protected method define_unique {args} {
	set fields($clsName,uqlist) [list {*}$args]
}


# ----------------------------------------------------------------------
# method  : define_autoincrement - method to be invoked by derived
#                                  classes from within
#                                  _define_autoincrement method.
# args    : a list containing fieldnames that are autoincrement/sequence
#           fields.
#
# returns : none
# ----------------------------------------------------------------------
protected method define_autoincrement {args} {
	set fields($clsName,sqlist) [list {*}$args]
}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method _define_primarykey {} {
	define_primarykey
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method _define_unique {} {
	define_unique
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected method _define_autoincrement {} {
	define_autoincrement
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private common fields; array set fields {}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private variable db


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method __get_condition {} {
	set condition [list]
	set pkcondition [__make_keyvaluepairs $fields($clsName,pklist)]
	if {$pkcondition != ""} {
		lappend condition $pkcondition
	}
	foreach uqlist $fields($clsName,uqlist) {
		set uqcondition [__make_keyvaluepairs $uqlist]
		if {$uqcondition != ""} {
			lappend condition $uqcondition
		}
	}
	return $condition
}

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method __prepare_getfields {} {
	if ![llength [array names fields -exact "$clsName,getlist"]] {
		set getlist ""
		foreach {opt val} [$this cget] {
			lappend getlist [string range $opt 1 end]
		}
		set fields($clsName,getlist) $getlist			
	}
}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method __prepare_insertfields {} {
	set sqlist $fields($clsName,sqlist)

	if ![llength [array names fields -exact "$clsName,insertlist"]] {
		set insertlist ""
		foreach {opt val} [$this cget] {
			set fname [string range $opt 1 end]
			if {[lsearch -exact $sqlist $fname] < 0} {
				lappend insertlist $fname
			}
		}
		set fields($clsName,insertlist) $insertlist			
	}
}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method __prepare_updatefields {} {
	set sqlist $fields($clsName,sqlist)
	set pklist $fields($clsName,pklist)

	if ![llength [array names fields -exact "$clsName,updatelist"]] {
		set updatelist ""
		foreach {opt val} [$this cget] {
			set fname [string range $opt 1 end]
			if {[lsearch -exact $pklist $fname] < 0 && [lsearch -exact $sqlist $fname] < 0} {
				lappend updatelist $fname
			}
		}
		set fields($clsName,updatelist) $updatelist			
	}
}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method __make_keyvaluepairs { fieldslist } {
	set keyslist [list]
	if [llength $fieldslist] {
		foreach field $fieldslist {
			if {[set val [$this cget -$field]] == "<undefined>"} {
				return ""
			}
			lappend keyslist $field $val
		}
	}

	return $keyslist
}


# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
private method __make_namevaluepairs { fieldslist } {
	set namevaluepairs [list]
	if [llength $fieldslist] {
		foreach field $fieldslist {
			if {[set val [$this cget -$field]] != "<undefined>"} {
				lappend namevaluepairs $field $val
			}
		}
	}

	return $namevaluepairs
}

# -------------------------------END------------------------------------
}
