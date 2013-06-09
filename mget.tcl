# mget.tcl --
#
# Multiple Records Getter interface that can be inherited by
# a particular table/view specific mget interface (eg., GetEmployees).
#
# Copyright (c) 2013 by Nagarajan Chinnasamy <nagarajanchinnasamy@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ----------------------------------------------------------------------
# class MGet
#
#
#
# ----------------------------------------------------------------------
itcl::class tdbo::MGet {
	inherit tdbo::Object

# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
constructor {db clsPath} {
	if {[namespace tail [info class]] == "MGet"} {
		return -code error "Error: Can't create MGet objects - abstract class."
	}
	if {$db == "" || ![$db isa Database]} {
		return -code error "Invalid db object type"
	}
	set [itcl::scope db] $db
	set [itcl::scope clsPath] $clsPath
}
	
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
destructor {
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public variable condition ""
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public variable format "dict"
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public variable fields "*"
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public variable orderby ""
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
public method execute {} {
	return [${clsPath}::mget $db -format $format -condition $condition -fields $fields -orderby $orderby]
}
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected variable db
# ----------------------------------------------------------------------
#
#
#
#
# ----------------------------------------------------------------------
protected variable clsPath

# ----------------------------------END---------------------------------
}
