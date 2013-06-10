package require struct::record 1.2.1

namespace eval ::tdao {}

namespace eval ::tdao::dao {
	variable undefined "<<dao-undefined>>"
	variable commands
	set commands [list define delete exists show]

	variable instcommands
	set instcommands [list configure cget reset add get save delete]

    variable schemadefn
	set schemadefn [dict create]

	variable instances
	set instances [dict create]

	variable schema_name
	variable flist
	variable sqlist
	variable pklist
	variable uqlist
	variable insertlist
	variable updatelist
	variable recordinst

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

proc ::tdao::dao::Define {schdefn_cmd schema_name fieldslist args} {
	variable schemadefn
	variable undefined

	set schdefn_cmd [_qualify $schdefn_cmd]
	if {[dict exists $schemadefn $schdefn_cmd]} {
		return -code error "Definition command $schdefn_cmd already exists"
	}

	set flist [list]
	set sqlist [list]
	set pklist [list]
	set uqlist [list]

	set recflist [list]
	foreach f $fieldslist {
		lassign $f n v
		lappend flist $n
		switch -- [llength $f] {
			1 {
				lappend recflist [list $n $undefined]
			}
			2 {
				lappend recflist $f
			}
			default {
				return -code error "Unsupported nested definition found in $schdefn_cmd."
			}
		}
	}

	set recdefn_cmd [format "%s%s" $schdefn_cmd "_record"]
	if {[catch {uplevel 1 [list struct::record define $recdefn_cmd $recflist]} recdefn_cmd]} {
		return -code error $recdefn_cmd
	}

	foreach {opt val} $args {
		switch -- $opt {
			-autoincrement {
				set sqlist $val
			}
			-primarykey {
				set pklist $val
			}
			-unique {
				set uqlist $val
			}
			default {
				return -code error "Invalid option $opt"
			}
		}
	}

	set insertlist [list]
	foreach fname $flist {
		if {[lsearch -exact $sqlist $fname] < 0} {
			lappend insertlist $fname
		}
	}

	set updatelist ""
	foreach fname $flist {
		if {[lsearch -exact $pklist $fname] < 0 && [lsearch -exact $sqlist $fname] < 0} {
			lappend updatelist $fname
		}
	}

	dict set schemadefn $schdefn_cmd -count 0
	dict set schemadefn $schdefn_cmd -schema_name $schema_name
	dict set schemadefn $schdefn_cmd -recdefn_cmd $recdefn_cmd
	dict set schemadefn $schdefn_cmd -flist $flist
	dict set schemadefn $schdefn_cmd -sqlist $sqlist
	dict set schemadefn $schdefn_cmd -pklist $pklist
	dict set schemadefn $schdefn_cmd -uqlist $uqlist
	dict set schemadefn $schdefn_cmd -insertlist $insertlist
	dict set schemadefn $schdefn_cmd -updatelist $updatelist	

    uplevel #0 [list interp alias {} $schdefn_cmd {} ::tdao::dao::Create $schdefn_cmd]

    return $schdefn_cmd
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

	set recdefn_cmd [dict get $schemadefn $schdefn_cmd -recdefn_cmd]
	if {[catch {uplevel 1 $recdefn_cmd #auto $args} recordinst]} {
		return -code error $recordinst
	}

    dict set instances $inst -schdefn_cmd $schdefn_cmd
    dict set instances $inst -schema_name [dict get $schemadefn $schdefn_cmd -schema_name]
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
	variable schemadefn
	variable instances
    variable instcommands

	variable schema_name
	variable flist
	variable sqlist
	variable pklist
	variable uqlist
	variable insertlist
	variable updatelist
	variable recordinst

    if {![dict exists $instances $inst]} {
        return -code error "Instance $inst does not exist"
    }

	if {[lsearch $instcommands $cmd] < 0} {
		return -code error "Sub command \"$cmd\" is not recognized. Must be [join $instcommands ,]"
	}

	set schdefn_cmd [dict get $instances $inst -schdefn_cmd]
	set schdefn [dict get $schemadefn $schdefn_cmd]

	dict update schdefn \
		-schema_name schema_name \
		-flist flist \
		-sqlist sqlist \
		-pklist pklist \
		-uqlist uqlist \
		-insertlist insertlist \
		-updatelist updatelist {
	}

	set recordinst [dict get $instances $inst -recordinst]

	switch -- $cmd {
		configure -
		cget -
		reset {
			return [uplevel 1 ::tdao::dao::${cmd} $inst $args]
		}
		default {
			return [uplevel 1 ::tdao::dao::${cmd} $inst $conn $args]
		}
	}
}

proc ::tdao::dao::configure {inst args} {
	variable recordinst

	if {[catch {uplevel 1 $recordinst configure $args} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dao::cget {inst args} {
	variable recordinst

	if {[catch {uplevel 1 $recordinst cget $args} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dao::reset {inst args} {
	variable instances
	variable schemadefn
	variable recordinst
	
	set schdefn_cmd [dict get $instances $inst -schdefn_cmd]
	set recdefn_cmd [dict get $schemadefn $schdefn_cmd -recdefn_cmd]

	set config [list]
	foreach m [struct::record show members $recdefn_cmd] {
		lassign $m n v
		lappend config -$n $v
	}

	uplevel 1 $recordinst configure $config
}


proc ::tdao::dao::add {inst conn args} {
	variable insertlist
	variable schema_name
	variable sqlist
	variable recordinst

	
	if {$args == ""} {
		set namevaluepairs [_make_namevaluepairs $insertlist]
	} else {
		set namevaluepairs [_make_namevaluepairs $args]
	}

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
	variable flist
	variable schema_name
	variable recordinst

	if {$args != ""} {
		set flist $args
	}

	if {[catch {$conn get $schema_name $flist [_get_condition] dict} result]} {
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
		$recordinst configure {*}[dict get $objcfg]
	}

	return $objcfg
}


proc ::tdao::dao::save {inst conn args} {
	variable updatelist
	variable schema_name

	if {$args != ""} {
		set updatelist $args
	}
	
	if {[catch {$conn update $schema_name [_make_namevaluepairs $updatelist] [_get_condition]} result]} {
		return -code error $result
	}

	return $result
}

proc ::tdao::dao::delete {inst conn args} {
	variable schema_name
	variable recordinst

	if {[catch {$conn delete $schema_name [_get_condition]} result]} {
		return -code error $result
	}

	if {$result} {
		clear $inst $conn
	}

	return $result
}

proc ::tdao::dao::_get_condition {} {
	variable pklist
	variable uqlist

	set condition [list]
	set pkcondition [_make_keyvaluepairs $pklist]
	if {$pkcondition != ""} {
		lappend condition $pkcondition
	}
	foreach uq $uqlist {
		set uqcondition [_make_keyvaluepairs $uq]
		if {$uqcondition != ""} {
			lappend condition $uqcondition
		}
	}
	return $condition
}

proc ::tdao::dao::_make_keyvaluepairs {fieldslist} {
	variable recordinst
	variable undefined

	set keyslist [list]
	if [llength $fieldslist] {
		foreach field $fieldslist {
			if {[set val [$recordinst cget -$field]] == $undefined} {
				return ""
			}
			lappend keyslist $field $val
		}
	}

	return $keyslist
}


proc ::tdao::dao::_make_namevaluepairs {fieldslist} {
	variable recordinst
	variable undefined

	set namevaluepairs [list]
	if [llength $fieldslist] {
		foreach field $fieldslist {
			if {[set val [$recordinst cget -$field]] != $undefined} {
				lappend namevaluepairs $field $val
			}
		}
	}

	return $namevaluepairs
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

namespace eval ::tdao {
    # Get 'dao::dao' into the general structure namespace.
    namespace import -force dao::dao
    namespace export dao
}
package provide tdao::dao 0.1.0
