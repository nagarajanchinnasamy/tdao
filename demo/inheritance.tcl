# ---------------------------------------------------------------------
# Step 0: Setup a database named employee using the employee_schema.sql
#         found in the respective sub-folder. Create necessary user
#         account and previleges.
# ---------------------------------------------------------------------

# ---------------------------------------------------------------------
# Step 1: Load tdao package and import dao and dbc commands
# ---------------------------------------------------------------------

package require tdao
namespace import -force tdao::dao::dao
namespace import -force tdao::dbc::dbc

# ---------------------------------------------------------------------
# Step 2: Load Database connectivity module and open a connection.
#         Un/Comment lines below as necessary
# ---------------------------------------------------------------------
set db [dbc load sqlite]
set conn [$db open [file normalize "sqlite/example.db"]]
#~ set db [dbc load postgres]
#~ set conn [$db open employee -user nagu -password Welcome123]
#~ set db [dbc load mariadb]
#~ set conn [$db open employee -user nagu -password Welcome123]

# ---------------------------------------------------------------------
# Step 3: Define Data Access Objects (DAO): address & employee
# ---------------------------------------------------------------------
puts [dao define Part \
	part {
		id
		name
		modelno
		serialno
		description
	} \
	-primarykey id \
	-autoincrement id]

puts [dao define HardDisk \
	harddisk {
		part_id
		capacity
		rpm
	} \
	-primarykey id \
	-autoincrement id \
	-inherits Part]

# ---------------------------------------------------------------------
# Step 4: Define Transactions: save_harddisk
# ---------------------------------------------------------------------
proc save_harddisk {conn op harddisk} {
	set part [Part #auto $conn {*}[$harddisk cget dict -id -name -modelno -serialno -description]]

	$conn begin
		switch $op {
			add {
				if {[catch {$part add} err]} {
					$conn rollback
					return -code error $err
				}
				$harddisk configure -part_id [$part cget -id]
				if {[catch {$harddisk add part_id capacity rpm} err]} {
					$conn rollback
					return -code error $err
				}
			}
			update {
				if {[catch {$part save} err]} {
					$conn rollback
					return -code error $err
				}
				if {[catch {$harddisk save part_id capacity rpm} err]} {
					$conn rollback
					return -code error $err
				}					
			}
		}
	$conn commit
	dao delete inst $part
	return 1
}

# ---------------------------------------------------------------------
# Step 5: Instantiate DAOs
# ---------------------------------------------------------------------
HardDisk hd1 $conn -name "harddrive" -modelno "hd0001" -serialno "INB100001" -description "blah blah" -capacity 500 -rpm 7200
puts "Before adding: [hd1 cget]"

# ---------------------------------------------------------------------
# Step 6: Add/Modify DAO
# ---------------------------------------------------------------------
if {[catch {save_harddisk $conn add hd1} err]} {
	puts "Saving harddisk failed...\nError: $err"
	$conn close
	exit
}

puts "After adding: [hd1 cget]"

# ---------------------------------------------------------------------
# Step 7: Clean up and close the database connection
# ---------------------------------------------------------------------
dao delete inst hd1
dao delete definitions Part HardDisk

$conn close
