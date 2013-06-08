package require struct::record 1.2.1

namespace eval ::tdao {}

namespace eval ::tdao::dao {
	variable commands
	set commands [list define delete exists show]

    variable schemadefn
	set schemadefn [dict create]

	namespace export dao
}

proc ::tdao::dao::dao {cmd args} {
    variable commands

	if {[lsearch $commands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $commands ,]"
	}

    set cmd [string totitle "$cmd"]
    return [uplevel 1 ::tdao::dao::${cmd} $args]

}

proc ::tdao::dao::Define {schema_name fieldnames args} {
	variable schemadefn
	
	set schema_name [_qualify $schema_name]

	if {[catch {uplevel 1 [list struct::record define ${schema_name}::record $fieldnames]} result]} {
		return -code error $result
	}

	dict set schemadefn $schema_name -record $result
	dict set schemadefn $schema_name -fields $fieldnames
	dict set schemadefn $schema_name -autoincrement [list]
	dict set schemadefn $schema_name -primarykey [list]
	dict set schemadefn $schema_name -unique [list]

	foreach {opt val} $args {
		-autoincrement -
		-primarykey -
		-unique {
			dict set schemadefn $schema_name $opt $val
		}
		default {
			return -code error "Invalid option $opt"
		}
	}

	_prepare_insertfields $schema_name
	_prepare_updatefields $schema_name

    uplevel #0 [list interp alias {} $schema_name {} ::tdao::dao::Create $schema_name]
    namespace eval ::tdao::dao${schema_name} {
        variable values
        variable instances

        set instances [list]
    }

    return $schema_name
}
proc ::tdao::dao::Create {schema_name inst conn args} {
	puts "In dao::Create"
}
proc ::tdao::dao::Delete {sub item} {
}
proc ::tdao::dao::Exists {sub item} {
}
proc ::tdao::dao::Show {what {schema_name ""}} {
}
proc ::tdao::dao::configure {inst {option ""} args} {
}
proc ::tdao::dao::cget {inst {option ""} args} {
}
proc ::tdao::dao::add {inst args} {
}
proc ::tdao::dao::get {inst args} {
}
proc ::tdao::dao::save {inst args} {
}
proc ::tdao::dao::delete {inst args} {
}
proc ::tdao::dao::_qualify {item {level 2}} {

    if {![string match "::*" "$item"]} {
        set ns [uplevel $level [list namespace current]]

        if {![string match "::" "$ns"]} {
            append ns "::"
        }
     
        set item "$ns${item}"
    }

    return "$item"

}


proc ::tdao::dao::_prepare_insertfields {schema_name} {
	variable schemadefn

	set sqlist [dict get $schemadefn $schema_name -autoincrement]

	if {![dict exists $schemadefn $schema_name -insertlist]} {
		set insertlist ""
		foreach fname [dict get $schemadefn $schema_name -fields] {
			if {[lsearch -exact $sqlist $fname] < 0} {
				lappend insertlist $fname
			}
		}
		dict set schemadefn $schema_name -insertlist $insertlist			
	}
}

proc ::tdao::dao::_prepare_updatefields {schema_name} {
	variable schemadefn

	set sqlist [dict get $schemadefn $schema_name -autoincrement]
	set pklist [dict get $schemadefn $schema_name -primarykey]

	if {![dict exists $schemadefn $schema_name -updatelist]} {
		set updatelist ""
		foreach fname [dict get $schemadefn $schema_name -fields] {
			if {[lsearch -exact $pklist $fname] < 0 && [lsearch -exact $sqlist $fname] < 0} {
				lappend updatelist $fname
			}
		}
		dict set schemadefn $schema_name -updatelist $updatelist
	}
}


namespace eval ::tdao {
    # Get 'dao::dao' into the general structure namespace.
    namespace import -force dao::dao
    namespace export dao
}
package provide tdao::dao 0.1.0
