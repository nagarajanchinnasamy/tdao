package require struct::record 1.2.1

namespace eval ::tdao {}

namespace eval ::tdao::dao {
	variable commands
	set commands [list define delete exists show]

	variable instcommands
	set instcommands [list configure cget add get save delete]

    variable schemadefn
	set schemadefn [dict create]

	variable instances
	set instances [dict create]

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
	
	set schdefn_cmd [_qualify $schema_name]
	if {[dict exists $schemadefn $schdefn_cmd]} {
		return -code error "A definition of schema $schema_name already exists"
	}

	set recdefn_cmd [format "%s%s" $schdefn_cmd "_record"]
	if {[catch {uplevel 1 [list struct::record define $recdefn_cmd $fieldnames]} recdefn_cmd]} {
		return -code error $recdefn_cmd
	}

	dict set schemadefn $schdefn_cmd -schema_name $schema_name
	dict set schemadefn $schdefn_cmd -recdefn_cmd $recdefn_cmd
	dict set schemadefn $schdefn_cmd -count 0
	dict set schemadefn $schdefn_cmd -fields $fieldnames
	dict set schemadefn $schdefn_cmd -autoincrement [list]
	dict set schemadefn $schdefn_cmd -primarykey [list]
	dict set schemadefn $schdefn_cmd -unique [list]

	foreach {opt val} $args {
		switch -- $opt {
			-autoincrement -
			-primarykey -
			-unique {
				dict set schemadefn $schdefn_cmd $opt $val
			}
			default {
				return -code error "Invalid option $opt"
			}
		}
	}

	_prepare_insertfields $schdefn_cmd
	_prepare_updatefields $schdefn_cmd

    uplevel #0 [list interp alias {} $schdefn_cmd {} ::tdao::dao::Create $schdefn_cmd]

    return $defnname
}

proc ::tdao::dao::Create {schdefn_cmd inst conn args} {
	variable schemadefn
	variable instances
	
	set inst [_qualify $inst]
    if {[dict exists $instances $inst]} {
        return -code error "Instance $inst already exists"
    }

	if {[string match "[_qualify #auto]" "$inst"]} {
		set c [dict get $schemadefn $schdefn_cmd -count]
        set inst [format "%s%s" $schdefn_cmd $c]
        dict set schemadefn $schdefn_cmd -count [incr c]
    }

    dict set instances $inst -schdefn_cmd $schdefn_cmd
    dict set instances $inst -schema_name [dict get $schemadefn $schdefn_cmd -schema_name]

	set recdefn_cmd [dict get $schemadefn $schdefn_cmd -recdefn_cmd]
	if {[catch {uplevel 1 $recdefn_cmd #auto $args} recordinst]} {
		return -code error $recordinst
	}
	dict set instances $inst -recordinst $recordinst

    uplevel #0 [list interp alias {} ${inst} {} ::tdao::dao::Cmd $inst $conn]

    return $inst	
}

proc ::tdao::dao::Delete {sub item} {
}

proc ::tdao::dao::Exists {sub item} {
}

proc ::tdao::dao::Show {what {schema_name ""}} {
}

proc ::tdao::dao::Cmd {inst conn cmd args} {
    variable instcommands

	if {[lsearch $instcommands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $instcommands ,]"
	}

    return [uplevel 1 ::tdao::dao::${cmd} $inst $conn $args]
}

proc ::tdao::dao::configure {inst conn args} {
	variable instances

    if {![dict exists $instances $inst]} {
        return -code error "Instance $inst does not exist"
    }

    set recordinst [dict get $instances $inst -recordinst]
	if {[catch {uplevel 1 $recordinst configure $args} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dao::cget {inst conn args} {
	variable instances

    if {![dict exists $instances $inst]} {
        return -code error "Instance $inst does not exist"
    }

    set recordinst [dict get $instances $inst -recordinst]
	if {[catch {uplevel 1 $recordinst cget $args} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dao::add {inst conn args} {
	variable schemadefn
	variable instances

	set schdefn_cmd [dict get $instances $inst -schdefn_cmd]
	set recordinst [dict get $instances $inst -recordinst]
	
	if {$args == ""} {
		set insertlist [dict get $schemadefn $schdefn_cmd -insertlist]
		set namevaluepairs [_make_namevaluepairs $recordinst $insertlist]
	} else {
		set namevaluepairs [_make_namevaluepairs $recordinst $args]
	}

	set schema_name [dict get $instances $inst -schema_name]
	set sqlist [dict get $schemadefn $schdefn_cmd -autoincrement]
	if {[catch {$conn insert $schema_name $namevaluepairs $sqlist} result]} {
		return -code error $result
	}
		
	lassign $result status sequencevalues

	if {$status} {
		if {$sequencevalues != ""} {
			set sequencecfg [dict create]
			dict for {fname val} $sequencevalues {
				dict set sequencecfg -${fname} $val
			}
			$recordinst configure {*}$sequencecfg
		}
	}
	return $status
}

proc ::tdao::dao::get {inst conn args} {
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
proc ::tdao::dao::save {inst conn args} {
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

proc ::tdao::dao::delete {inst conn args} {
	if {[catch {$db delete [${clsName}::schema_name] [__get_condition]} result]} {
		return -code error $result
	}

	if {$result} {
		clear
	}

	return $result
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

proc ::tdao::dao::_get_condition {} {
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

proc ::tdao::dao::_make_keyvaluepairs {$recordinst fieldslist } {
	set keyslist [list]
	if [llength $fieldslist] {
		foreach field $fieldslist {
			if {[set val [$recordinst cget -$field]] == ""} {
				return ""
			}
			lappend keyslist $field $val
		}
	}

	return $keyslist
}


proc ::tdao::dao::_make_namevaluepairs {$recordinst fieldslist } {
	set namevaluepairs [list]
	if [llength $fieldslist] {
		foreach field $fieldslist {
			if {[set val [$recordinst cget -$field]] != ""} {
				lappend namevaluepairs $field $val
			}
		}
	}

	return $namevaluepairs
}


namespace eval ::tdao {
    # Get 'dao::dao' into the general structure namespace.
    namespace import -force dao::dao
    namespace export dao
}
package provide tdao::dao 0.1.0
