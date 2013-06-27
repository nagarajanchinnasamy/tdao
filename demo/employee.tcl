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
puts [dao define Address \
	address {
		id
		addrline1
		addrline2
		{city Bangalore}
		{postalcode 560001}
		{country India}
	} \
	-primarykey id \
	-autoincrement id]

puts [dao define Employee \
	employee {
		id
		name
		rollno
		address_id
	} \
	-primarykey id \
	-autoincrement id]

# ---------------------------------------------------------------------
# Step 4: Define Transactions: save_employee
# ---------------------------------------------------------------------
proc save_employee {conn op emp addr} {
	$conn begin
		switch $op {
			add {
				if {[catch {$addr add} err]} {
					$conn rollback
					return -code error $err
				}

				$emp configure -address_id [$addr cget -id]
				if {[catch {$emp add} err]} {
					$conn rollback
					return -code error $err
				}
			}
			update {
				if {[catch {$addr save} err]} {
					$conn rollback
					return -code error $err
				}
				if {[catch {$emp save} err]} {
					$conn rollback
					return -code error $err
				}					
			}
		}
	$conn commit

	return 1
}

# ---------------------------------------------------------------------
# Step 5: Instantiate DAOs address & employee
# ---------------------------------------------------------------------
Employee emp $conn -name "Employee Name1" -rollno "INBNG0001"
puts "Employee before adding: [emp cget]"

Address addr $conn \
	-addrline1 "Address Line 1" \
	-addrline2 "Address Line 2"
puts "Address before adding: [addr cget]"

# ---------------------------------------------------------------------
# Step 6: Add/Modify employee & address
# ---------------------------------------------------------------------
if {[catch {save_employee $conn add emp addr} err]} {
	puts "Saving employee failed...\nError: $err"
	$conn close
	exit
}

puts "Employee after adding: [emp cget]"
puts "Address after adding: [addr cget]"

# Modify and save Address object.
addr configure \
	-addrline1 "Updated Address Line 1" \
	-addrline2 "Updated Address Line 2" \
	-city "Updated City Name" \
	-country "Updated Country Name" \
	-postalcode "Updated Postal Code"
addr save

# Check if the changes are reflected by retrieving it from database
addr reset
puts "Reset address: [addr cget]"
addr configure -id [emp cget -address_id]
addr get
puts "Modified address: [addr cget]"

# ---------------------------------------------------------------------
# Step 7: Clean up and close the database connection
# ---------------------------------------------------------------------
dao delete inst addr emp
dao delete def Address Employee

$conn close
